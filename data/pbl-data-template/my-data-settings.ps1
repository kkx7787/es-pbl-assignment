# 메모장에서 '=' 오른쪽 값과 field 규칙만 자신의 주제에 맞게 바꿉니다.
# 이 파일은 생성기가 읽는 PowerShell 변수 설정입니다. 제공된 형식을 유지하고 값과 규칙만 수정합니다.
$IndexName = 'scout-players-2627-v1'
$DocumentCount = 6000
$Seed = 20262027
$IdPrefix = 'P'
$IdField = 'player_id'
$SampleCount = 30
# choice와 tags 규칙이 참조하는 도메인별 후보 목록입니다.
# 구단명은 실존 구단이 아닌 가상 이름입니다. 실존 구단명을 쓰면 무작위로 뽑힌
# league와 어긋나 'Arsenal / EFL League Two' 같은 모순이 생깁니다.
$Vocabularies = [ordered]@{
  first_names = @('Callum', 'Idris', 'Marcus', 'Owen', 'Rafael', 'Tobias', 'Niall', 'Emeka', 'Lucas', 'Hugo', 'Finley', 'Mateo')
  last_names  = @('Whitfield', 'Bankole', 'Delaney', 'Ashcroft', 'Moreau', 'Lindqvist', 'Okafor', 'Vasquez', 'Hartley', 'Renner', 'Doyle', 'Kowalski')
  clubs       = @('Ashford United', 'Northgate City', 'Riverton Athletic', 'Kingsmere FC', 'Elderfield Town', 'Westbrook Rovers', 'Harrowgate FC', 'Stonebridge City', 'Fairhaven Athletic', 'Marlowe Town')
  leagues     = @('Premier League', 'Premier League U21', 'EFL Championship', 'EFL League One', 'EFL League Two', 'La Liga', 'Bundesliga', 'Serie A')
  nationalities = @('England', 'Wales', 'Ireland', 'Scotland', 'France', 'Spain', 'Germany', 'Brazil', 'Nigeria', 'Netherlands')
  positions   = @('GK', 'CB', 'LB', 'RB', 'DM', 'CM', 'AM', 'LW', 'RW', 'ST')
  traits      = @('측면 돌파', '전진 패스', '제공권 경합', '박스 안 마무리', '압박 강도', '세트피스 처리', '탈압박 첫 터치', '대인 방어')
  tags        = @('progressive-passer', 'set-piece-taker', 'high-press', 'aerial-duels', 'u23', 'loan-candidate')
}
# 문서는 위에서 아래 순서로 만들어집니다.
# template는 앞에서 만든 field와 {{sequence}}을 사용할 수 있습니다.
$FieldRules = @(
  @{ Name = 'player_id'; Kind = 'id'; Digits = 4 }
  @{ Name = 'first_name'; Kind = 'choice'; Source = 'first_names' }
  @{ Name = 'last_name'; Kind = 'choice'; Source = 'last_names' }
  @{ Name = 'name'; Kind = 'template'; Template = '{{first_name}} {{last_name}}' }
  @{ Name = 'club'; Kind = 'choice'; Source = 'clubs' }
  @{ Name = 'league'; Kind = 'weighted_choice'; Values = @(
      @{ Value = 'Premier League'; Weight = 9 },
      @{ Value = 'Premier League U21'; Weight = 7 },
      @{ Value = 'EFL Championship'; Weight = 10 },
      @{ Value = 'EFL League One'; Weight = 10 },
      @{ Value = 'EFL League Two'; Weight = 10 },
      @{ Value = 'La Liga'; Weight = 13 },
      @{ Value = 'Bundesliga'; Weight = 13 },
      @{ Value = 'Serie A'; Weight = 13 }
    ) }
  @{ Name = 'nationality'; Kind = 'choice'; Source = 'nationalities' }
  @{ Name = 'detailed_position'; Kind = 'choice'; Source = 'positions' }
  @{ Name = 'secondary_positions'; Kind = 'tags'; Source = 'positions'; MinItems = 1; MaxItems = 2; MissingRatio = 0.10 }
  @{ Name = 'preferred_foot'; Kind = 'weighted_choice'; Values = @(
      @{ Value = '왼발'; Weight = 24 },
      @{ Value = '오른발'; Weight = 72 },
      @{ Value = '양발'; Weight = 4 }
    ) }
  @{ Name = 'age'; Kind = 'integer'; Min = 16; Max = 38 }
  @{ Name = 'height_cm'; Kind = 'integer'; Min = 165; Max = 198 }
  @{ Name = 'is_homegrown'; Kind = 'boolean'; TrueRatio = 0.35 }
  @{ Name = 'contract_until'; Kind = 'date'; Start = '2027-06-30T00:00:00Z'; End = '2031-06-30T00:00:00Z' }
  @{ Name = 'market_value_eur'; Kind = 'integer'; Min = 200000; Max = 90000000 }
  @{ Name = 'appearances'; Kind = 'integer'; Min = 0; Max = 38 }
  @{ Name = 'minutes'; Kind = 'integer'; Min = 0; Max = 3420 }
  @{ Name = 'goals'; Kind = 'integer'; Min = 0; Max = 30 }
  @{ Name = 'assists'; Kind = 'integer'; Min = 0; Max = 20 }
  @{ Name = 'trait'; Kind = 'choice'; Source = 'traits' }
  @{ Name = 'scout_note'; Kind = 'template'; Template = '{{preferred_foot}} {{detailed_position}} 자원. 강점은 {{trait}}.' }
  @{ Name = 'tags'; Kind = 'tags'; Source = 'tags'; MinItems = 1; MaxItems = 3; MissingRatio = 0.03 }
  @{ Name = 'is_synthetic'; Kind = 'boolean'; TrueRatio = 1.0 }
)
