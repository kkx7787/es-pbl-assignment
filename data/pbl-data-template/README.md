# 개인 PBL 대량 데이터 템플릿

개인 data/pbl-data-template로 폴더 전체를 복사한다. 기존 수정본은 덮어쓰지 않는다.
현재 수업은 [개인 데이터 생성 가이드](../practice/DATA_GENERATION_GUIDE.md), [학생교재](../student-workbook.md)를 따른다. 이 링크는 배포 원본에서 사용하는 링크다. 개인 복사본에서는 배포 저장소의 가이드를 열어 본다.

## 실행 기준

- 개인 mapping 정본: 개인 루트 elasticsearch/index-create.json. T12에서 생성한 index를 재사용한다.
- 이 폴더의 elasticsearch/create-index-template.http는 도서 참고 예시다. 기존 개인 mapping 대신 다시 실행하지 않는다.
- my-data-settings.ps1: IndexName·IdField·후보/규칙·seed를 본인 mapping에 맞춘다. 기본 DocumentCount=1000, SampleCount=30.
- generator/generate-data.ps1: 합성 데이터 생성. MappingFile을 지정하면 field/type을 사전 확인한다.
- data-contract.ps1 / validate-data.ps1: 로컬 NDJSON·ID·schema·해시 검사. 폴더 전체 복사가 필요하다.
- load-data.ps1: 로컬 검증 및 index 존재 확인 후 Bulk 전송. 실제 ES 분포는 별도 확인한다.

## 개인 작업 폴더에서 실행

~~~powershell
.\generator\generate-data.ps1 -SettingsFile .\my-data-settings.ps1 -MappingFile ..\..\elasticsearch\index-create.json
.\validate-data.ps1 -SettingsFile .\my-data-settings.ps1 -MappingFile ..\..\elasticsearch\index-create.json
.\load-data.ps1 -SettingsFile .\my-data-settings.ps1 -MappingFile ..\..\elasticsearch\index-create.json -DockerDirectory "C:\수업\es-5days-pbl-course\day-01\docker"
~~~

DockerDirectory는 실제 Day1 docker 위치로 바꾼다. 기본 scalar/배열 외 복합 객체는 별도 생성 설계가 필요하다. 경계 사례 고정은 생성 가이드의 FixedDocumentsFile을 사용한다.
Kind: id, choice, weighted_choice, integer, decimal, date, boolean, tags, template. 비율0~1, 음수 가중치 금지, template 참조는 먼저 생성되는 결측 없는 field만 허용한다.

## 결과·제출

generated/자기-index-1000.ndjson은 전체 파일이므로 기본 제외한다.
생성 설정/코드, 개인 mapping, 대표3건, generated/자기-index-sample-30.ndjson, generation-summary.json과 실제 검증 결과는 제출한다.
개인 .gitignore에는 data/pbl-data-template/generated/자기-index-1000.ndjson처럼 실제 경로를 적는다. generated 전체를 제외하지 않는다.
현재 설정/파일 해시가 다르면 다시 생성해야 한다. 오류를 index 전체 삭제로 해결하지 않는다.
