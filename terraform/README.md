# Terraform

## 모듈 구성

| Root 모듈 | 역할                                           | backend key            |
| --------- | ---------------------------------------------- | ---------------------- |
| bootstrap | tfstate 저장소(S3) + 잠금(DynamoDB) 프로비저닝 | 로컬 tfstate           |
| dev       | EKS Dev 인프라 프로비저닝                      | dev/terraform.tfstate  |
| argo      | ArgoCD 설치 및 root App 배포(kubectl_manifest) | argo/terraform.tfstate |

| Child 모듈  | 역할                                                          |
| ----------- | ------------------------------------------------------------- |
| acm         | HTTPS 인증서 발급 및 갱신                                     |
| argocd      | ArgoCD 설치 및 root App 배포(kubectl_manifest)                |
| eks         | 클러스터, AWS LBC(Load Balancer Controller) 설치 및 IRSA 설정 |
| ecr         | Docker 이미지 레지스트리                                      |
| github-oidc | GitHub Action OIDC                                            |
| network     | VPC, Nat Instance, Route Table, IGW(Internet GateWay)         |
| rds         | 단일 RDS (Dev)                                                |
| redis       | 단일 Redis (Dev)                                              |
| route53     | A 레코드로 DNS 등록                                           |
| s3          | ALB 로그 기록 저장                                            |
| security    | SG 규칙, EKS IAM Role 설정                                    |
| waf         | 웹 애플리케이션 방화벽                                        |

## 실행 가이드

### Apply

```
1. terraform/environments/bootstrap로 이동 ⇒ terraform apply (최초 1회만, destroy 금지)
2. terraform/environments/dev로 이동 ⇒ terraform apply (VPC/EKS/RDS 등 EKS 인프라)
3. terraform/environments/argo로 이동 ⇒ terraform apply — ArgoCD 설치 + root App (여기서 ALB 생성됨)
4. terraform/environments/dev/terraform.tfvars의 alb_dns_name 변수에 ALB DNS 값을 기입
5. terraform/environments/dev로 이동 ⇒ terraform apply 다시 실행 (Route53 레코드 생성)
```

> ⚠️ external-dns 도입 시 4~5번 단계는 제거 예정

### Destroy

```
1. terraform/environments/argo로 이동 ⇒ terraform destroy (root App 삭제 → finalizer cascade → ALB 자동 소멸)
2. terraform/environments/dev로 이동 ⇒ terraform destroy
```

> ⚠️ 모두 destroy ⇒ terraform/environments/dev/terraform.tfvars의 alb_dns_name 변수 빈 값으로 초기화 (이전 ALB 주소로 레코드를 만들기 때문)

## ArgoCD UI 접속

1. 아래 명령어를 통해 비밀번호 확인

```
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

2. https://argocd.hbksv.cloud 접속 ⇒ 아이디(**admin**)와 비밀번호 입력

> ⚠️ 도메인 접속은 Apply 4~5번 단계(Route53 레코드 생성)까지 끝나야 가능합니다. 그 전에 UI가 필요하면 port-forward로 접속하세요.
>
> ```
> kubectl port-forward svc/argocd-server -n argocd 8080:80
> ```
>
> ⇒ http://localhost:8080 (server.insecure 모드라 HTTP로 접속)

## 보완할 점

- base 폴더의 ConfigMap/Secret은 현재 수동 apply -> Secret은 ESO를 통해 자동화 예정
- ALB DNS도 External DNS를 사용하여 자동화 예정
