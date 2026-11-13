# Terraform

## 모듈 구성

| Root 모듈 | 역할                                                                | backend key            |
| --------- | ------------------------------------------------------------------- | ---------------------- |
| bootstrap | tfstate 저장소(S3) + 잠금(DynamoDB) + 더미 데이터 버킷 프로비저닝   | 로컬 tfstate           |
| dev       | EKS Dev 인프라 프로비저닝 + ArgoCD 설치·root App(`root-dev`) 배포   | dev/terraform.tfstate  |
| prod      | EKS Prod 인프라 프로비저닝 + ArgoCD 설치·root App(`root-prod`) 배포 | prod/terraform.tfstate |

| Child 모듈      | 역할                                                                                 |
| --------------- | ------------------------------------------------------------------------------------ |
| acm             | HTTPS 인증서 발급 및 갱신                                                            |
| alarm           | CloudWatch 알람(RDS·ElastiCache·ALB) → SNS → Lambda → Discord (Prod)                 |
| argocd          | ArgoCD 설치 및 root App 배포(Helm `argocd-apps`)                                     |
| eks             | 클러스터, 노드 그룹, EKS 애드온, AWS LBC(Load Balancer Controller) 설치 및 IRSA 설정 |
| ecr             | Docker 이미지 레지스트리                                                             |
| elasticache     | Redis (Dev 단일 노드 / Prod primary + replica, AUTH·TLS)                             |
| github-oidc     | GitHub Action OIDC                                                                   |
| kms             | EBS·RDS 암호화용 CMK (Prod)                                                          |
| network         | VPC, NAT(Dev NAT Instance / Prod AZ별 NAT Gateway), Route Table, IGW                 |
| parameter-store | 앱 시크릿·DB 접속 정보 SSM 파라미터 (ESO가 동기화)                                   |
| rds             | PostgreSQL (Dev 단일 인스턴스 / Prod 서비스별 인스턴스 5대)                          |
| route53         | 호스팅 영역 (레코드는 external-dns가 등록)                                           |
| s3              | ALB 액세스 로그 버킷                                                                 |
| security        | SG 규칙, EKS IAM Role 설정                                                           |
| waf             | 웹 애플리케이션 방화벽 (Prod)                                                        |

## 실행 가이드

### Apply

- **Dev**

  ```
  1. terraform/environments/bootstrap로 이동 ⇒ terraform apply (최초 1회만, destroy 금지)

  2. terraform/environments/dev로 이동 ⇒ terraform apply (VPC/EKS/RDS 등 EKS 인프라 + ArgoCD 설치)
  ```

- **Prod**

  ```
  1. terraform/environments/bootstrap로 이동 ⇒ terraform apply (최초 1회만, destroy 금지)

  2. terraform/environments/prod로 이동 ⇒ terraform apply (VPC/EKS/RDS 등 EKS 인프라 + ArgoCD 설치)

  3. spot-gateway 대상 그룹이 생긴 것을 확인한 뒤 terraform/environments/prod에서 한 번 더 terraform apply (WAF 연결 + ALB 알람)

  ```

### Destroy

- **Dev**

  ```
  1. aws eks update-kubeconfig --name spot-dev-cluster --region ap-northeast-2

  2. kubectl delete app root-dev -n argocd (root App 삭제 → finalizer cascade)

  3. terraform/environments/dev로 이동 ⇒ terraform destroy
  ```

- **Prod**

  ```
  1. aws eks update-kubeconfig --name spot-prod-cluster --region ap-northeast-2

  2. kubectl delete app root-prod -n argocd (root App 삭제 → finalizer cascade)

  3. terraform/environments/prod로 이동 ⇒ terraform destroy
  ```

## ArgoCD UI 접속

- 아래 명령어를 통해 비밀번호 확인

  ```

  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d

  ```

- https://argocd.hbksv.com 접속 ⇒ 아이디(=**admin**)와 비밀번호 입력
