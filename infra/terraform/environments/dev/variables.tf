# =============================================================================
# 프로젝트 기본 설정
# =============================================================================
variable "project" {
  description = "프로젝트 이름"
  type        = string
  default     = "spot"
}

variable "environment" {
  description = "환경 (dev, prod)"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

# =============================================================================
# 네트워크 설정
# =============================================================================
variable "vpc_cidr" {
  description = "VPC CIDR 블록"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public 서브넷 CIDR 목록"
  type        = map(string)
  default = {
    "a" = "10.0.1.0/24"
    "c" = "10.0.2.0/24"
  }
}

variable "private_subnet_cidrs" {
  description = "Private 서브넷 CIDR 목록"
  type        = map(string)
  default = {
    "a" = "10.0.10.0/24"
    "c" = "10.0.20.0/24"
  }
}

variable "availability_zones" {
  description = "사용할 가용 영역"
  type        = map(string)
  default = {
    "a" = "ap-northeast-2a"
    "c" = "ap-northeast-2c"
  }
}

variable "nat_instance_type" {
  description = "NAT Instance 타입"
  type        = string
  default     = "t3.nano"
}

# =============================================================================
# 데이터베이스 설정
# =============================================================================
variable "db_name" {
  description = "데이터베이스 이름"
  type        = string
  default     = "spotdb"
}

variable "db_username" {
  description = "데이터베이스 사용자 이름"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "데이터베이스 비밀번호"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS 인스턴스 클래스"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "RDS 스토리지 크기 (GB)"
  type        = number
  default     = 20
}

variable "db_engine_version" {
  description = "PostgreSQL 버전"
  type        = string
  default     = "16"
}

# =============================================================================
# MSA Services Configuration
# =============================================================================
variable "services" {
  description = "MSA 서비스 구성 맵"
  type = map(object({
    container_port    = number
    cpu               = string
    memory            = string
    desired_count     = number
    health_check_path = string
    path_patterns     = list(string)
    priority          = number
    environment_vars  = map(string)
  }))
  default = {
    "gateway" = {
      container_port    = 8080
      cpu               = "256"
      memory            = "512"
      desired_count     = 1
      health_check_path = "/actuator/health"
      # 모든 트래픽을 Gateway로 몰아주기 위해 /* 패턴 사용
      path_patterns = ["/*"]
      priority      = 1 # 가장 높은 우선순위
      environment_vars = {
        SERVICE_NAME = "spot-gateway"
      }
    }
    "order" = {
      container_port    = 8082
      cpu               = "256"
      memory            = "512"
      desired_count     = 1
      health_check_path = "/actuator/health"
      path_patterns     = ["/api/orders/*", "/api/orders"]
      priority          = 100
      environment_vars = {
        SERVICE_NAME = "spot-order"
        DB_SCHEMA    = "orders"
      }
    }
    "payment" = {
      container_port    = 8084
      cpu               = "256"
      memory            = "512"
      desired_count     = 1
      health_check_path = "/actuator/health"
      path_patterns     = ["/api/payments/*", "/api/payments"]
      priority          = 200
      environment_vars = {
        SERVICE_NAME = "spot-payment"
        DB_SCHEMA    = "payments"
      }
    }
    "store" = {
      container_port    = 8083
      cpu               = "256"
      memory            = "512"
      desired_count     = 1
      health_check_path = "/actuator/health"
      path_patterns     = ["/api/stores/*", "/api/stores"]
      priority          = 300
      environment_vars = {
        SERVICE_NAME = "spot-store"
        DB_SCHEMA    = "stores"
      }
    }
    "user" = {
      container_port    = 8081
      cpu               = "256"
      memory            = "512"
      desired_count     = 1
      health_check_path = "/actuator/health"
      path_patterns     = ["/api/users/*", "/api/users", "/api/auth/*", "/api/admin/*"]
      priority          = 400
      environment_vars = {
        SERVICE_NAME = "spot-user"
        DB_SCHEMA    = "users"
      }
    }
  }
}

variable "enable_service_connect" {
  description = "ECS Service Connect 활성화 여부"
  type        = bool
  default     = true
}

# =============================================================================
# DNS / SSL 설정
# =============================================================================
variable "domain_name" {
  description = "도메인 이름"
  type        = string
  default     = "spotorder.org"
}

variable "create_api_domain" {
  description = "API Gateway 커스텀 도메인 생성 여부"
  type        = bool
  default     = true
}

# =============================================================================
# WAF 설정
# =============================================================================
variable "waf_rate_limit" {
  description = "5분당 최대 요청 수 (Rate Limiting)"
  type        = number
  default     = 2000
}

variable "waf_log_retention_days" {
  description = "WAF 로그 보관 일수"
  type        = number
  default     = 30
}


# =============================================================================
# S3 설정
# =============================================================================
variable "s3_log_transition_days" {
  description = "로그를 Glacier로 이동하는 일수"
  type        = number
  default     = 30
}

variable "s3_log_expiration_days" {
  description = "로그 삭제 일수"
  type        = number
  default     = 90
}

# =============================================================================
# ElastiCache (Redis) 설정
# =============================================================================
variable "redis_node_type" {
  description = "Redis 노드 타입"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_num_cache_clusters" {
  description = "Redis 클러스터 수 (1=단일, 2+=복제본)"
  type        = number
  default     = 1 # dev 환경에서는 단일 노드
}

variable "redis_engine_version" {
  description = "Redis 엔진 버전"
  type        = string
  default     = "7.1"
}

# =============================================================================
# Monitoring 설정
# =============================================================================
variable "alert_email" {
  description = "알람 알림 받을 이메일 (빈 값이면 구독 안함)"
  type        = string
  default     = ""
}

# =============================================================================
# JWT 설정
# =============================================================================
variable "jwt_secret" {
  description = "JWT 시크릿 키"
  type        = string
  sensitive   = true
  default     = "jmXDQDnLqV+lOaPKMR06v4+RQ7aj2cj8LR+zgPOlz/GS989tptPtAmIpyaZHrsLOPqKoVtPus28YeXZTL8O8nw=="
}

variable "jwt_expire_ms" {
  description = "JWT 만료 시간 (밀리초)"
  type        = number
  default     = 3600000
}

variable "refresh_token_expire_days" {
  description = "리프레시 토큰 만료 일수"
  type        = number
  default     = 14
}

# =============================================================================
# Mail 설정
# =============================================================================
variable "mail_username" {
  description = "SMTP 사용자 이름 (Gmail)"
  type        = string
  default     = ""
}

variable "mail_password" {
  description = "SMTP 비밀번호 (Gmail 앱 비밀번호)"
  type        = string
  sensitive   = true
  default     = ""
}

# =============================================================================
# Toss Payments 설정
# =============================================================================
variable "toss_secret_key" {
  description = "Toss Payments 시크릿 키"
  type        = string
  sensitive   = true
  default     = ""
}

variable "toss_customer_key" {
  description = "Toss Payments 고객 키"
  type        = string
  default     = "customer_1"
}

# =============================================================================
# Service 설정
# =============================================================================
variable "service_active_regions" {
  description = "서비스 활성 지역"
  type        = string
  default     = "종로구"
}

# =============================================================================
# Standby Mode (비용 절감)
# =============================================================================
variable "standby_mode" {
  description = "스탠바이 모드 (true면 모든 서비스 desired_count = 0)"
  type        = bool
  default     = false
}

# =============================================================================
# Kafka 설정
# =============================================================================
variable "kafka_instance_type" {
  description = "Kafka EC2 인스턴스 타입"
  type        = string
  default     = "t3.small"
}

variable "kafka_volume_size" {
  description = "Kafka EBS 볼륨 크기 (GB)"
  type        = number
  default     = 20
}

variable "kafka_log_retention_hours" {
  description = "Kafka 메시지 보관 시간"
  type        = number
  default     = 168 # 7일
}


# =============================================================================
# eks 설정
# =============================================================================
variable "cluster_name" {
  type    = string
  default = "spot-cluster-test"
}

variable "cluster_version" {
  type    = string
  default = "1.29"
}

# =============================================================================
# k8s_bootstrap.tf
# =============================================================================
variable "alb_controller_chart_version" {
  type        = string
  description = "Helm chart version for aws-load-balancer-controller"
  default     = "1.7.2"
}

variable "create_alb_record" {
  type    = bool
  default = false
}
variable "eks_public_access_cidrs" {
  description = "CIDRs allowed to access EKS public endpoint"
  type        = list(string)
  default     = []
}
