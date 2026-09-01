#!/usr/bin/env python3
"""macOS 포팅본 · 강사 배포 generator/generate-data.ps1과 validate-data.ps1의 규칙을 그대로 옮긴 구현.

- 원본 .ps1 파일은 수정하지 않는다. 이 파일은 별도 구현이다.
- 설정 원본은 계속 ../my-data-settings.ps1 하나뿐이다. 이 스크립트가 그 파일을 파싱한다.
- 난수는 .NET System.Random(seed)의 subtractive lagged Fibonacci 알고리즘을 재구현했다.
  PowerShell이 쓰는 것과 같은 알고리즘이므로 같은 seed면 같은 순서가 나오도록 의도했다.
  다만 이 환경에 pwsh가 없어 실제 PowerShell 출력과의 바이트 동일성은 교차 검증하지 못했다.
"""
import argparse, hashlib, json, os, re, sys
from datetime import datetime, timedelta, timezone

# ---------------------------------------------------------------- .NET Random
class DotNetRandom:
    MBIG = 2147483647
    MSEED = 161803398

    def __init__(self, seed):
        arr = [0] * 56
        subtraction = self.MBIG if seed == -2147483648 else abs(seed)
        mj = self.MSEED - subtraction
        arr[55] = mj
        mk = 1
        for i in range(1, 55):
            ii = (21 * i) % 55
            arr[ii] = mk
            mk = mj - mk
            if mk < 0:
                mk += self.MBIG
            mj = arr[ii]
        for _ in range(1, 5):
            for i in range(1, 56):
                arr[i] -= arr[1 + (i + 30) % 55]
                if arr[i] < 0:
                    arr[i] += self.MBIG
        self._arr = arr
        self._inext = 0
        self._inextp = 21

    def _internal_sample(self):
        i = self._inext + 1
        if i >= 56:
            i = 1
        p = self._inextp + 1
        if p >= 56:
            p = 1
        ret = self._arr[i] - self._arr[p]
        if ret == self.MBIG:
            ret -= 1
        if ret < 0:
            ret += self.MBIG
        self._arr[i] = ret
        self._inext = i
        self._inextp = p
        return ret

    def sample(self):
        return self._internal_sample() * (1.0 / self.MBIG)

    def next_double(self):
        return self.sample()

    def next(self):                        # $Random.Next()
        return self._internal_sample()

    def next_max(self, max_value):         # $Random.Next($n)
        return int(self.sample() * max_value)

    def next_range(self, min_value, max_value):   # $Random.Next($a, $b)  상한 제외
        return int(self.sample() * (max_value - min_value)) + min_value


# ------------------------------------------------- PowerShell 설정 파일 파서
class PsParseError(Exception):
    pass


class PsParser:
    """my-data-settings.ps1이 쓰는 부분집합만 읽는다: 문자열, 정수, 실수, @(), @{}, [ordered]@{}."""

    def __init__(self, text):
        self.s = text
        self.i = 0

    def error(self, msg):
        line = self.s.count("\n", 0, self.i) + 1
        raise PsParseError(f"{line}행: {msg}")

    def skip(self, newline_is_space=True):
        while self.i < len(self.s):
            c = self.s[self.i]
            if c == "#":
                while self.i < len(self.s) and self.s[self.i] != "\n":
                    self.i += 1
            elif c == "\n":
                if not newline_is_space:
                    return
                self.i += 1
            elif c in " \t\r":
                self.i += 1
            else:
                return

    def eat(self, literal):
        self.skip()
        if self.s.startswith(literal, self.i):
            self.i += len(literal)
            return True
        return False

    def expect(self, literal):
        if not self.eat(literal):
            self.error(f"'{literal}'가 필요합니다")

    def parse_value(self):
        self.skip()
        if self.i >= len(self.s):
            self.error("값이 끝났습니다")
        if self.s.startswith("[ordered]", self.i):
            self.i += len("[ordered]")
            self.skip()
        c = self.s[self.i]
        if c == "'":
            return self.parse_string()
        if self.s.startswith("@(", self.i):
            return self.parse_array()
        if self.s.startswith("@{", self.i):
            return self.parse_hashtable()
        m = re.match(r"-?\d+\.\d+", self.s[self.i:])
        if m:
            self.i += m.end()
            return float(m.group(0))
        m = re.match(r"-?\d+", self.s[self.i:])
        if m:
            self.i += m.end()
            return int(m.group(0))
        m = re.match(r"\$(true|false)", self.s[self.i:], re.I)
        if m:
            self.i += m.end()
            return m.group(1).lower() == "true"
        self.error(f"해석할 수 없는 값: {self.s[self.i:self.i+20]!r}")

    def parse_string(self):
        self.i += 1
        out = []
        while True:
            if self.i >= len(self.s):
                self.error("닫히지 않은 문자열")
            c = self.s[self.i]
            if c == "'":
                if self.s.startswith("''", self.i):
                    out.append("'")
                    self.i += 2
                    continue
                self.i += 1
                return "".join(out)
            out.append(c)
            self.i += 1

    def parse_array(self):
        self.i += 2
        items = []
        while True:
            self.skip()
            if self.eat(")"):
                return items
            items.append(self.parse_value())
            self.skip()
            while self.eat(","):
                self.skip()

    def parse_hashtable(self):
        self.i += 2
        table = {}
        while True:
            self.skip()
            if self.eat("}"):
                return table
            m = re.match(r"[A-Za-z_][A-Za-z0-9_]*", self.s[self.i:])
            if not m:
                self.error(f"key가 필요합니다: {self.s[self.i:self.i+20]!r}")
            key = m.group(0)
            self.i += m.end()
            self.expect("=")
            table[key] = self.parse_value()
            self.skip()
            while self.eat(";") or self.eat(","):
                self.skip()


def load_settings(path):
    text = open(path, encoding="utf-8-sig").read()
    settings = {}
    for m in re.finditer(r"^\$([A-Za-z_][A-Za-z0-9_]*)\s*=", text, re.M):
        parser = PsParser(text)
        parser.i = m.end()
        settings[m.group(1)] = parser.parse_value()
    required = ["IndexName", "DocumentCount", "Seed", "IdPrefix", "IdField",
                "SampleCount", "Vocabularies", "FieldRules"]
    for name in required:
        if settings.get(name) is None:
            raise PsParseError(f"설정 파일에 ${name} 변수가 없습니다.")
    return settings


# --------------------------------------------------------------- 규칙 엔진
def required(rule, name):
    value = rule.get(name)
    if value is None or (isinstance(value, str) and not value.strip()):
        raise ValueError(f"field '{rule.get('Name')}'의 {name} 설정이 필요합니다.")
    return value


def rule_value(rule, document, sequence, rnd, vocab, id_prefix):
    kind = required(rule, "Kind")
    if kind == "id":
        digits = int(rule.get("Digits", 5))
        return f"{id_prefix}-{sequence:0{digits}d}"
    if kind == "choice":
        source = required(rule, "Source")
        if source not in vocab:
            raise ValueError(f"field '{rule['Name']}'의 Source '{source}'가 Vocabularies에 없습니다.")
        values = vocab[source]
        if not values:
            raise ValueError("선택 후보가 비어 있습니다.")
        return values[rnd.next_max(len(values))]
    if kind == "weighted_choice":
        values = required(rule, "Values")
        total = float(sum(float(v["Weight"]) for v in values))
        if total <= 0:
            raise ValueError("weighted_choice의 Weight 합계는 0보다 커야 합니다.")
        point = rnd.next_double() * total
        running = 0.0
        for item in values:
            running += float(item["Weight"])
            if point < running:
                return item["Value"]
        return values[-1]["Value"]
    if kind == "integer":
        return rnd.next_range(int(required(rule, "Min")), int(required(rule, "Max")) + 1)
    if kind == "decimal":
        lo, hi = float(required(rule, "Min")), float(required(rule, "Max"))
        return round(lo + rnd.next_double() * (hi - lo), int(rule.get("Digits", 2)))
    if kind == "date":
        start = parse_dt(required(rule, "Start"))
        end = parse_dt(required(rule, "End"))
        if end < start:
            raise ValueError(f"field '{rule['Name']}'의 End는 Start보다 빠를 수 없습니다.")
        span = (end - start).total_seconds()
        moment = start + timedelta(seconds=int(rnd.next_double() * span))
        return moment.strftime("%Y-%m-%dT%H:%M:%SZ")
    if kind == "boolean":
        return rnd.next_double() < float(required(rule, "TrueRatio"))
    if kind == "tags":
        source = required(rule, "Source")
        if source not in vocab:
            raise ValueError(f"field '{rule['Name']}'의 Source '{source}'가 Vocabularies에 없습니다.")
        pool = list(vocab[source])
        keys = [rnd.next() for _ in pool]                    # Sort-Object { $Random.Next() }
        values = [v for _, v in sorted(zip(keys, range(len(pool))), key=lambda p: p[0])]
        values = [pool[i] for i in values]
        lo, hi = int(required(rule, "MinItems")), int(required(rule, "MaxItems"))
        if lo < 1 or hi < lo or hi > len(values):
            raise ValueError(f"field '{rule['Name']}'의 MinItems/MaxItems 범위가 후보 수와 맞지 않습니다.")
        return values[: rnd.next_range(lo, hi + 1)]
    if kind == "template":
        return fill_template(required(rule, "Template"), document, sequence)
    raise ValueError(f"지원하지 않는 Kind입니다: {kind}")


def parse_dt(text):
    return datetime.strptime(text, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)


def fill_template(template, document, sequence):
    value = template.replace("{{sequence}}", str(sequence))
    for key, item in document.items():
        replacement = " ".join(str(x) for x in item) if isinstance(item, list) else ps_str(item)
        value = value.replace("{{" + key + "}}", replacement)
    if re.search(r"\{\{.+?\}\}", value):
        raise ValueError(f"template에 아직 채워지지 않은 값이 있습니다: {template}")
    return value


def ps_str(value):
    if isinstance(value, bool):
        return "True" if value else "False"
    return str(value)


# ------------------------------------------------- data-contract.ps1 대응 검사
INT_LIMITS = {
    "integer": (-2147483648, 2147483647),
    "short": (-32768, 32767),
    "byte": (-128, 127),
    "long": (-(2 ** 63), 2 ** 63 - 1),
}
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}(T.*(Z|[+-]\d{2}:\d{2}))?$")


def assert_document_mapping(document, properties):
    for name, value in document.items():
        definition = properties.get(name)
        if definition is None:
            raise ValueError(f"Undefined mapping field: {name}")
        es_type = definition.get("type")
        if value is None:
            continue
        for item in (value if isinstance(value, list) else [value]):
            if item is None:
                continue
            if es_type in ("text", "keyword"):
                if not isinstance(item, str):
                    raise ValueError(f"Expected string: {name}")
            elif es_type == "boolean":
                if not isinstance(item, bool):
                    raise ValueError(f"Expected boolean: {name}")
            elif es_type in INT_LIMITS:
                if isinstance(item, bool) or not isinstance(item, int):
                    raise ValueError(f"Expected integer: {name}")
                lo, hi = INT_LIMITS[es_type]
                if item < lo or item > hi:
                    raise ValueError(f"Integer outside mapping range: {name}")
            elif es_type in ("float", "double", "half_float", "scaled_float"):
                if isinstance(item, bool) or not isinstance(item, (int, float)):
                    raise ValueError(f"Expected finite number: {name}")
            elif es_type == "date":
                if not isinstance(item, str) or not DATE_RE.match(item):
                    raise ValueError(f"Expected ISO date: {name}")
            else:
                raise ValueError(
                    f"Local template supports flat scalar fields and arrays only; "
                    f"unsupported mapping type '{es_type}' on {name}.")


def sha256_upper(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest().upper()


def compact_json(obj):
    return json.dumps(obj, ensure_ascii=False, separators=(",", ":"))


def load_mapping_properties(path):
    mapping = json.load(open(path, encoding="utf-8"))
    properties = mapping.get("mappings", {}).get("properties")
    if not properties:
        raise ValueError("MappingFile must contain a complete creation body with mappings.properties.")
    return properties


# ------------------------------------------------------------------ generate
def validate_config(settings):
    index_name = settings["IndexName"]
    if not re.match(r"^[a-z0-9][a-z0-9_-]*$", index_name):
        raise ValueError("IndexName은 소문자, 숫자, 하이픈, 밑줄만 사용합니다.")
    if settings["DocumentCount"] < settings["SampleCount"] or settings["SampleCount"] < 1:
        raise ValueError("DocumentCount는 SampleCount 이상이고 SampleCount는 1 이상이어야 합니다.")
    if settings["DocumentCount"] > 100000:
        raise ValueError("DocumentCount must be an integer up to 100000 for this classroom template.")
    rules = settings["FieldRules"]
    if settings["IdField"] not in [r["Name"] for r in rules]:
        raise ValueError(f"IdField '{settings['IdField']}'에 해당하는 field 규칙이 없습니다.")
    known = {}
    for rule in rules:
        name = rule.get("Name", "")
        if not re.match(r"^[A-Za-z][A-Za-z0-9_]*$", name) or name in known:
            raise ValueError(f"Invalid or duplicate field Name: {name}")
        for ratio in ("MissingRatio", "TrueRatio"):
            if ratio in rule and not (0 <= float(rule[ratio]) <= 1):
                raise ValueError(f"{ratio} must be between 0 and 1: {name}")
        if rule.get("Kind") in ("integer", "decimal") and float(rule["Min"]) > float(rule["Max"]):
            raise ValueError(f"Min exceeds Max: {name}")
        if rule.get("Kind") == "weighted_choice":
            for item in rule["Values"]:
                if item.get("Value") is None or item.get("Weight") is None or float(item["Weight"]) < 0:
                    raise ValueError(f"Invalid weighted choice: {name}")
        if rule.get("Kind") == "template":
            for ref in re.findall(r"\{\{(.+?)\}\}", rule["Template"]):
                if ref != "sequence" and (ref not in known or float(known[ref].get("MissingRatio", 0)) > 0):
                    raise ValueError(f"Template must reference an earlier, non-missing field: {ref}")
        known[name] = rule
    id_rule = known[settings["IdField"]]
    if id_rule.get("Kind") != "id" or float(id_rule.get("MissingRatio", 0)) > 0:
        raise ValueError("IdField must use Kind=id without missing values.")
    return known


def cmd_generate(args):
    settings_path = os.path.abspath(args.settings_file)
    settings = load_settings(settings_path)
    known = validate_config(settings)
    out_dir = os.path.abspath(args.output_directory or os.path.join(os.path.dirname(settings_path), "generated"))

    properties = None
    mapping_path = None
    if args.mapping_file:
        mapping_path = os.path.abspath(args.mapping_file)
        properties = load_mapping_properties(mapping_path)
        for name in known:
            if name not in properties:
                raise ValueError(f"FieldRule absent from mapping: {name}")

    os.makedirs(out_dir, exist_ok=True)
    index_name = settings["IndexName"]
    count = settings["DocumentCount"]
    sample_count = settings["SampleCount"]
    id_field = settings["IdField"]
    bulk_path = os.path.join(out_dir, f"{index_name}-{count}.ndjson")
    sample_path = os.path.join(out_dir, f"{index_name}-sample-{sample_count}.ndjson")
    summary_path = os.path.join(out_dir, "generation-summary.json")

    rnd = DotNetRandom(int(settings["Seed"]))
    vocab = settings["Vocabularies"]
    bulk_lines, sample_lines = [], []
    for sequence in range(1, count + 1):
        document = {}
        for rule in settings["FieldRules"]:
            if "MissingRatio" in rule and rnd.next_double() < float(rule["MissingRatio"]):
                continue
            document[rule["Name"]] = rule_value(rule, document, sequence, rnd, vocab, settings["IdPrefix"])
        if id_field not in document:
            raise ValueError(f"문서 {sequence} 에 IdField '{id_field}'가 없습니다.")
        if properties:
            assert_document_mapping(document, properties)
        action = compact_json({"index": {"_index": index_name, "_id": document[id_field]}})
        body = compact_json(document)
        bulk_lines += [action, body]
        if sequence <= sample_count:
            sample_lines += [action, body]

    write_lines(bulk_path, bulk_lines)
    write_lines(sample_path, sample_lines)

    summary = {
        "index": index_name,
        "document_count": count,
        "seed": settings["Seed"],
        "id_field": id_field,
        "files": {"bulk": os.path.basename(bulk_path), "sample": os.path.basename(sample_path)},
        "field_kinds": [{"name": r["Name"], "kind": r["Kind"]} for r in settings["FieldRules"]],
        "generated_at": "deterministic-from-seed",
        "fixed_document_count": 0,
        "settings_sha256": sha256_upper(settings_path),
        "bulk_sha256": sha256_upper(bulk_path),
        "mapping_sha256": sha256_upper(mapping_path) if mapping_path else None,
        "generator": "macos/pbl_generator.py (generate-data.ps1 포팅본)",
    }
    with open(summary_path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
    print(f"생성 완료: {count} 건")
    print(f"Bulk 파일: {bulk_path}")
    print(f"표본 파일: {sample_path}")


def write_lines(path, lines):
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        for line in lines:
            fh.write(line + "\n")


# ------------------------------------------------------------------ validate
def cmd_validate(args):
    settings_path = os.path.abspath(args.settings_file)
    settings = load_settings(settings_path)
    index_name, count, id_field = settings["IndexName"], settings["DocumentCount"], settings["IdField"]
    data_file = os.path.abspath(args.data_file or os.path.join(
        os.path.dirname(settings_path), "generated", f"{index_name}-{count}.ndjson"))
    summary_path = os.path.join(os.path.dirname(data_file), "generation-summary.json")
    summary = json.load(open(summary_path, encoding="utf-8"))
    if summary["index"] != index_name or summary["document_count"] != count:
        raise ValueError("Summary differs from settings; regenerate.")
    if summary.get("settings_sha256") and summary["settings_sha256"] != sha256_upper(settings_path):
        raise ValueError("Settings changed since generation; regenerate.")
    if summary.get("bulk_sha256") and summary["bulk_sha256"] != sha256_upper(data_file):
        raise ValueError("Bulk file changed since generation; regenerate.")
    properties = None
    if args.mapping_file:
        mapping_path = os.path.abspath(args.mapping_file)
        if summary.get("mapping_sha256") and summary["mapping_sha256"] != sha256_upper(mapping_path):
            raise ValueError("Mapping changed since generation; recheck and regenerate.")
        properties = load_mapping_properties(mapping_path)

    raw = open(data_file, "rb").read()
    if not raw or raw[-1] != 10:
        raise ValueError("NDJSON must end with newline.")
    if raw[:3] == b"\xef\xbb\xbf":
        raise ValueError("NDJSON must be UTF-8 without BOM.")
    lines = raw.decode("utf-8").split("\n")[:-1]
    if len(lines) != count * 2:
        raise ValueError("NDJSON line count differs from expected document count.")
    ids = set()
    for i in range(0, len(lines), 2):
        action = json.loads(lines[i])
        doc = json.loads(lines[i + 1])
        if not isinstance(doc, dict):
            raise ValueError(f"Source must be a JSON object at line {i + 2}.")
        if len(action) != 1 or "index" not in action or action["index"].get("_index") != index_name:
            raise ValueError(f"Invalid action/index at line {i + 1}.")
        doc_id = str(action["index"].get("_id") or "")
        if not doc_id.strip() or doc_id in ids:
            raise ValueError(f"Empty or duplicate ID at line {i + 1}.")
        ids.add(doc_id)
        if id_field and str(doc.get(id_field)) != doc_id:
            raise ValueError(f"Business ID does not match _id at line {i + 2}.")
        if properties:
            assert_document_mapping(doc, properties)
    print(f"LOCAL CHECK PASS: {len(ids)} documents, unique IDs, target index and NDJSON verified. "
          "This is not an Elasticsearch indexing result.")


def main():
    ap = argparse.ArgumentParser(description="PBL 데이터 생성기 macOS 포팅본")
    sub = ap.add_subparsers(dest="command", required=True)
    g = sub.add_parser("generate")
    g.add_argument("--settings-file", required=True)
    g.add_argument("--mapping-file")
    g.add_argument("--output-directory")
    g.set_defaults(func=cmd_generate)
    v = sub.add_parser("validate")
    v.add_argument("--settings-file", required=True)
    v.add_argument("--mapping-file")
    v.add_argument("--data-file")
    v.set_defaults(func=cmd_validate)
    args = ap.parse_args()
    try:
        args.func(args)
    except Exception as exc:
        print(f"실패: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
