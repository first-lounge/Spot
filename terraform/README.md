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

3. k8s/deploy의 update-waf.sh 실행 ⇒ diff 확인 ⇒ PR로 dev merge (WAF ARN 값 수정 및 git 업데이트)

4. terraform/environments/argo로 이동 ⇒ terraform apply — ArgoCD 설치 + root App (여기서 ALB 생성됨)
```

> ⚠️ **3번(WAF ARN 갱신·머지)은 반드시 4번(argo apply)보다 먼저 완료해야 합니다.** spot-app이 첫 sync 진행 시, 새 WAF ARN이 dev 브랜치에 merge돼 있지 않으면 에러가 발생하기 때문입니다.

### Destroy

```
1. kubectl delete app root-dev -n argocd (root App 삭제 → finalizer cascade → ALB 자동 소멸)
2. terraform/environments/argo로 이동 ⇒ terraform destroy
3. terraform/environments/dev로 이동 ⇒ terraform destroy
```

> ⚠️ 1번 실행 후 kubectl get application -n argocd로 root 외 전부 삭제된 걸 확인한 뒤 나머지 실행

## ArgoCD UI 접속

1. 아래 명령어를 통해 비밀번호 확인

```
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

2. https://argocd.hbksv.cloud 접속 ⇒ 아이디(=**admin**)와 비밀번호 입력
