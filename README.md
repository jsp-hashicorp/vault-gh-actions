# GitHub Actions과 HashiCorp Vault를 활용하여 안전한 GitOps Workflow 만들기
  
  이번 세션에서는 안전한 파이프라인 구축을 위해 HashiCorp Vault와 GitHub Actions를 사용하여 최신 GitOps Workflow 적용방안을 알아봅니다.

## 필요 사항
1. Github 계정
2. Terraform Cloud 계정
3. Vault 서버
4. AWS 계정 (free tier로 테스트 가능)
5. Terraform Helper


## 사전 작업 사항 
이미 Github 계정과 AWS 계정 (Free Tier도 가능)은 있다는 가정 하에 다음 순서로 데모 환경을 구성. <br>
아래 작업 전, 다음 Repo를 Fork 할 것 <br>
[https://github.com/jsp-hashicorp/vault-gh-actions](https://github.com/jsp-hashicorp/vault-gh-actions)


### 1. Terraform Cloud 환경 구성
1. 테라폼 클라우드 가입하기 <br>
다음 링크 상의 정보를 확인하여 Terraform Cloud에 가입하여 계정을 생성한다.<br>
[Sign up for Terraform Cloud](https://learn.hashicorp.com/tutorials/terraform/cloud-sign-up?in=terraform/cloud-get-started) <br>

> Start from scratch를 선택하여 Organization을 생성.


2.  Workspace 생성 <br>
다음 링크 상의 정보를 참고하여, Workspace를 생성 <br>
[Create a Workspace](https://learn.hashicorp.com/tutorials/terraform/cloud-workspace-create?in=terraform/cloud-get-started) <br>
[CLI Driven Run Workflow](https://www.terraform.io/cloud-docs/run/cli)<br>

> Workspace 생성 시 CLI Driven Workflow를 선택하여 하여 구성.<br>
Workspace > Settings > General Settings에서 다음 내용 설정<br>
  Executio Mode: Remote, Apply Method: Auto Apply


3. Terraform API 토큰 생성<br>
다음 명령어를 수행하여 Terraform API 토큰을 생성, 로컬 파일에 저장. <br>
이 단계에서 생성된 토큰 값을 Vault [Terraform Cloud 시크릿 엔진](https://www.vaultproject.io/docs/secrets/terraform)에서 사용하여 필요 시 동적으로 생성 예정.

```bash
terraform login
```

> 참고 링크 <br>
[Log in to Terraform Cloud from the CLI](https://learn.hashicorp.com/tutorials/terraform/cloud-login?in=terraform/0-13)


4. Fork한 Repo상의 remote_backend.tf 수정 <br>
다음과 같이 파일 수정
```terraform
terraform {
  cloud {
    organization = "단계 1에서 만든 Organization 이름"

    workspaces {
      name = "단계 2에서 만든 Workspace 이름"
    }
  }
}
```

5. Terraform Cloud 환경 변수 설정<br>
Variables 탭에서 아래 변수값 설정. 우선 임의의 값으로 설정.<br>
Vault와 연계하여, 파이프 라인 동작 시 자동으로 설정.

```
환경 변수로 설정 
AWS_ACCESS_KEY_ID		
AWS_SECRET_ACCESS_KEY (SENSITIVE 설정)

Terraform 변수로 설정
region	
placeholder
width
height
prefix
```

### 2. Vault 서버 구성

1. Vault Enterprise Trial 라이센스 신청<br>
다음 링크에 접속하여 Vault Enterprise 30일 Trial 라이센스 신청<br>
[Vault Enterprise Trial 라이센스 신청](https://www.hashicorp.com/products/vault/trial)


2. Vault 서버 구성<br>
다음 링크 상의 내용을 참고하여 Vault 서버를 구성하고 잠금 해제할 것. <br>
이 때 Unseal Key와 Initial Root Token을 잘 보관할 것.   <br>
[Deploy Vault](https://learn.hashicorp.com/tutorials/vault/getting-started-deploy?in=vault/getting-started)<br>

> Enterprise License를 적용은 아래와 같이 환경 변수나 설정 파일로 적용.<br>
환경 변수로 적용하는 경우 : $ export VAULT_LICENSE_PATH=/etc/vault.d/license.hclic <br>
설정파일로 적용하는 경우 : license_path = "/etc/vault.d/license.hclic" (서버 구성 파일 하단에 추가)<br>


3. 시크릿 엔진 구성
AWS 시크릿 엔진, Key/Value 시크릿 엔진 그리고 Terraform Cloud 시크릿 엔진을 구성<br>
[AWS Secret Engine](https://www.vaultproject.io/docs/secrets/aws) - 사용 중인 방식(iam_user, assumed_role, federation_token)을 선택하여 구성<br>
[AWS Dynmacic Secrets](https://learn.hashicorp.com/tutorials/vault/getting-started-dynamic-secrets?in=vault/getting-started)<br>
[Versioned Key/Value Secrets Engine](https://learn.hashicorp.com/tutorials/vault/versioned-kv?in=vault/secrets-management)<br>
[Terraform Cloud Secrets Engine](https://learn.hashicorp.com/tutorials/vault/terraform-secrets-engine?in=vault/secrets-management)<br>

위에서 구성한 시크릿 엔진을 사용하여 계정 생성 및 조회가 정상적으로 진행되는 경우, 다음 단계를 수행.


4. Vault Token 생성
위에서 생성된 시크릿 엔진에 접속 가능한 정책을 설정.
역할 명이나 Path는 단계 3에서 설정한 경로와 역할명을 사용하여 생성할 것
```hcl
# file name : readonly_policy.hcl
# sts AssumeRole 사용 시
path "aws/sts/{생성할 Role 이름}" {
  capabilities = [ "create","update" ]
}

# key/value 값 조회
path "secret/data/tfvars/*" {
  capabilities = ["read"]
}

# Get credentials from the terraform secrets engine
path "terraform/creds/my-user" {
  capabilities = [ "read" ]
}

```

위 정책 파일을 사용하여 정책 생성 및 Token 생성
```bash
$ vault policy write ro readonly_policy.hcl
$ vault token create -policy=ro
Key                  Value
---                  -----
token                s.iyNUhq8Ov4hIAx6snw5mB2nL <-- 해당 값을 VAULT_TOKEN이란 이름으로 Github secret으로 저장. 
token_accessor       maMfHsZfwLB6fi18Zenj3qh6
token_duration       768
token_renewable      true
token_policies       ["default","ro"]
identity_policies    []
policies             ["default","ro"]
```

### 3. Terraform Helper 구성
다음 Repo를 참고하여 Terraform Helper를 구성하여, Terraform Cloud 상의 변수 설정 시 사용.<br>
[The Terraform Helper](https://github.com/hashicorp-community/tf-helper)

사용법 또한 위 링크 상의 문서 참고. 금번 데모의 경우 [pushvar 기능](https://github.com/hashicorp-community/tf-helper/blob/release/tfh/usr/share/doc/tfh/tfh_pushvars.md) 사용


### 4. Github Actions 구성
다음 링크 상에 Vault Github Actions 사용 방법을 확인하고, 사전 작업 단계에서 Fork한 Repo 상의 Secret으로 VAULT_TOKEN 값을 설정. (이 예제에서는 s.iyNUhq8Ov4hIAx6snw5mB2nL)
[Vault Github Actions](https://learn.hashicorp.com/tutorials/vault/github-actions?in=vault/app-integration) <br>

GitHub Actions 구동 시 Self-hosted Runner를 사용.<br> Vault를 HCP Vault 또는 Public IP로 접근 가능한 곳에 구성한 경우, GitHub Hosted Runner 사용 가능.

Github Actions는 다음과 같은 3개의 Job으로 구성<br>
1. 시크릿 조회 및 TFC 변수 설정
2. EC2 배포
3. 시크릿 회수 및 TFC 변수 설정 초기화

#### 1. 시크릿 조회 및 TFC 변수 설정
주요 내용
```yaml
pre-vault:
    name: 1. 시크릿 조회 및 TFC 변수 설정
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v2
      - name: 1.1 시크릿 조회 및 생성
        id: import
        uses: hashicorp/vault-action@v2.4.0
        with:
          url: {{VAULT_ADDR}} --> 로컬 구동 시 http://127.0.0.1:8200, Vault 구성 환경에 따라 상이.
          tlsSkipVerify: true
          token: ${{ secrets.VAULT_TOKEN }} --> GitHub 시크릿으로 설정된 VAULT_TOKEN값
          secrets: | 
            secrets/data/tfvar prefix | prefix ; --> Terraform Cloud에서 사용할 변수 값 조회
            (( 중략 ))
            terraform/creds/my-user token | TF_API_TOKEN ; --> Terraform Cloud에 접근 가능한 API 토큰 생성
            aws/sts/vault-demo-jsp access_key | AWS_ACCESS_KEY_ID ; --> AWS Access Key 생성
            aws/sts/vault-demo-jsp secret_key | AWS_SECRET_ACCESS_KEY ; --> AWS Secret key 생성

      - name: 1.2 TFC Workspace 변수 설정
        id: set_var
        run: |
         cd {Terraform Helper 설치 경로}
         ./tfh pushvars -org ${{ env.TF_ORGANIZATION }} -name 'vault-gh-actions' -token ${{ env.TF_API_TOKEN }} -var 'prefix=${{ env.prefix }}' -overwrite prefix
         ./tfh pushvars -org ${{ env.TF_ORGANIZATION }} -name 'vault-gh-actions' -token ${{ env.TF_API_TOKEN }} -var 'height=${{ env.height }}' -overwrite height
        (( 중략 ))
         ./tfh pushvars -org ${{ env.TF_ORGANIZATION }} -name 'vault-gh-actions' -token ${{ env.TF_API_TOKEN }} -env-var 'AWS_ACCESS_KEY_ID=${{ env.AWS_ACCESS_KEY_ID }}' -overwrite-env AWS_ACCESS_KEY_ID --> 환경 변수로 설정
         ./tfh pushvars -org ${{ env.TF_ORGANIZATION }} -name 'vault-gh-actions' -token ${{ env.TF_API_TOKEN }} -senv-var 'AWS_SECRET_ACCESS_KEY=${{ env.AWS_SECRET_ACCESS_KEY }}' -overwrite-env AWS_SECRET_ACCESS_KEY --> 환경 변수를 Sensitive로 설정
       (( 생략 ))
```

#### 2. EC2 배포
대부분의 내용은 Terraform Github Actions의 내용을 대부분 사용.<br>
다음 부분을 먼저 수행 후 [Terraform GitHub Actions](https://learn.hashicorp.com/tutorials/terraform/github-actions) 내용 수행.<br>
```yaml
  terraform: 
    name: 2. EC2 인스턴스 배포
    runs-on: self-hosted
    needs: pre-vault
    steps:
      - name: Checkout
        uses: actions/checkout@v2
      
      - name: 2.1 임시 작업 토큰 생성
        id: import
        uses: hashicorp/vault-action@v2.4.0
        with:
          url: {{VAULT_ADDR}} --> 로컬 구동 시 http://127.0.0.1:8200, Vault 구성 환경에 따라 상이.
          tlsSkipVerify: true
          token: ${{ secrets.VAULT_TOKEN }}
          secrets: |
            terraform/creds/my-user token | TF_API_TOKEN
```
#### 3. 시크릿 회수 및 TFC 변수 설정 초기화
작업을 위한 시크릿을 생성 조회하는 부부은 `1. 시크릿 조회 및 TFC 변수 설정`단계와 동일<br>
변수 설정을 초기화 하고, 시크릿을 삭제하는 부분만 아래와 같이 다르게 동작함.

```yaml
      - name: 3.2 임시 계정 회수 (TF API TOKEN, AWS access key) 및 TFC 환경 변수 초기화
        id: unset_var
        run: |
         cd  cd {Terraform Helper 설치 경로}
         ./tfh pushvars -org ${{ env.TF_ORGANIZATION }} -name 'vault-gh-actions' -token ${{ env.TF_API_TOKEN }} -var 'prefix=env.prefix' -overwrite prefix
   (( 중략 ))
         ./tfh pushvars -org ${{ env.TF_ORGANIZATION }} -name 'vault-gh-actions' -token ${{ env.TF_API_TOKEN }} -env-var 'AWS_ACCESS_KEY_ID=AWS_ACCESS_KEY_ID' -overwrite-env AWS_ACCESS_KEY_ID
    (( 중략 ))
         export VAULT_ADDR=http://127.0.0.1:8200
         export VAULT_TOKEN=${{ secrets.VAULT_TOKEN }}
         vault lease revoke -sync -prefix ${{ env.STS_PREFIX }}  --> AWS 접속 정보 폐기
         vault lease revoke -sync -prefix terraform/creds/my-user  --> Terraform API 토큰 페기
```

## 데모
Terraform Configuration Template을 수정하고 push 하게 되면, GitHub Actions가 동작하면서 다음과 같이 동작한다.<br>
시연 시 main.tf상의 `aws_vpc` 리소스에 다음과 같이 Tag값을 추가 후 Commit & Push 할 것.
```hcl
resource "aws_vpc" "snapshot" {
  cidr_block           = var.address_space
  enable_dns_hostnames = true

  tags = {
    name = "${var.prefix}-vpc-${var.region}"
    environment = "snapshot"
    owner = "test"
    ttl = "48"
  }
}
```

1. 시크릿 조회 및 TFC 변수 설정
   1. Terraform Cloud 상의 Workspace 접속을 위한 Terraform API Token을 생성
   2. 해당 Token을 사용하여 각종 변수 설정
2. EC2 배포<br>
     단계 1에서 설정한 변수값을 사용하여 AWS EC2 인스턴스 및 Application 배포
3. 시크릿 회수 및 TFC 변수 설정 초기화
   1. 작업용 Terraform API 토큰 생성 및 AWS access_key, secret_key 폐기
   2. Terraform Cloud 상 모든 환경 변수 초기화
   3. 전체 과정에서 생성된 Terraform API 토큰 삭제

## Key Takeaways
파이프 파인 각 단계에서 필요한 각종 시크릿을 최소 권한의 원칙과 필요 시 사용 후 폐기하는 방식으로 보다 안전하게 사용할 수 있는 방법을 확인