#!/bin/bash

# 1. 설정 변수 (여기를 본인 환경에 맞게 수정하세요)
export RDSHOST="spot-dev.cj6iq2cow597.ap-northeast-2.rds.amazonaws.com"
export DB_USER="spot_admin"
export PGPASSWORD="spot-postgres"

# psql 설치 확인 (없으면 설치 시도)
if ! command -v psql &> /dev/null; then
    echo "psql이 없습니다. 설치를 진행합니다..."
    brew install postgresql
fi

echo "--- 1. 데이터베이스 생성 시작 ---"
# DB 생성은 postgres 기본 DB에 접속해서 수행해야 함
# (이미 존재한다는 에러가 나도 무시하고 진행하도록 || true 추가)
psql -h $RDSHOST -U $DB_USER -d postgres -c "CREATE DATABASE spot_temporal;" || true
psql -h $RDSHOST -U $DB_USER -d postgres -c "CREATE DATABASE spot_visibility;" || true

echo "--- 2. 스키마 파일 다운로드 ---"
curl -L https://raw.githubusercontent.com/temporalio/temporal/master/schema/postgresql/v12/temporal/schema.sql -o temporal_main.sql
curl -L https://raw.githubusercontent.com/temporalio/temporal/master/schema/postgresql/v12/visibility/schema.sql -o temporal_visibility.sql

echo "--- 3. 기본 스키마 적용 (Tables) ---"
# Main DB 적용
psql -h $RDSHOST -U $DB_USER -d spot_temporal -f temporal_main.sql
# Visibility DB 적용
psql -h $RDSHOST -U $DB_USER -d spot_visibility -f temporal_visibility.sql

echo "--- 4. [Main DB] spot_temporal 버전 정보 주입 (v1.18) ---"
# 로컬에서 추출한 1.18 버전 데이터 주입
psql -h $RDSHOST -U $DB_USER -d spot_temporal <<EOF
-- 기존 테이블 정리
DROP TABLE IF EXISTS schema_version;
DROP TABLE IF EXISTS schema_update_history;

-- 테이블 생성
CREATE TABLE schema_version (
    version_partition INTEGER NOT NULL,
    db_name VARCHAR(255),
    creation_time TIMESTAMP,
    curr_version VARCHAR(64),
    min_compatible_version VARCHAR(64),
    PRIMARY KEY (version_partition, curr_version)
);

CREATE TABLE schema_update_history (
    version_partition INTEGER NOT NULL,
    year INTEGER,
    month INTEGER,
    update_time TIMESTAMP,
    description VARCHAR(255),
    manifest_md5 VARCHAR(64),
    new_version VARCHAR(64),
    old_version VARCHAR(64),
    PRIMARY KEY (version_partition, year, month, update_time)
);

-- 데이터 주입
INSERT INTO schema_version (version_partition, db_name, creation_time, curr_version, min_compatible_version)
VALUES (0, 'spot_temporal', '2026-02-16 06:23:36.639674', '1.18', '1.0');

INSERT INTO schema_update_history (version_partition, year, month, update_time, description, manifest_md5, new_version, old_version) VALUES
(0, 2026, 2, '2026-02-16 06:23:35.080222', 'initial version', '', '0.0', '0'),
(0, 2026, 2, '2026-02-16 06:23:35.984134', 'base version of schema', '55b84ca114ac34d84bdc5f52c198fa33', '1.0', '0.0'),
(0, 2026, 2, '2026-02-16 06:23:35.998756', 'schema update for cluster metadata', '58f06841bbb187cb210db32a090c21ee', '1.1', '1.0'),
(0, 2026, 2, '2026-02-16 06:23:36.006823', 'schema update for RPC replication', 'c6bdeea21882e2625038927a84929b16', '1.2', '1.1'),
(0, 2026, 2, '2026-02-16 06:23:36.015033', 'schema update for kafka deprecation', '3beee7d470421674194475f94b58d89b', '1.3', '1.2'),
(0, 2026, 2, '2026-02-16 06:23:36.023060', 'schema update for cluster metadata cleanup', 'c53e2e9cea5660c8a1f3b2ac73cdb138', '1.4', '1.3'),
(0, 2026, 2, '2026-02-16 06:23:36.038957', 'schema update for cluster_membership, executions and history_node tables', 'bfb307ba10ac0fdec83e0065dc5ffee4', '1.5', '1.4'),
(0, 2026, 2, '2026-02-16 06:23:36.050353', 'schema update for queue_metadata', '978e1a6500d377ba91c6e37e5275a59b', '1.6', '1.5'),
(0, 2026, 2, '2026-02-16 06:23:36.164937', 'create cluster metadata info table to store cluster information and executions to store tiered storage queue', '366b8b49d6701a6a09778e51ad1682ed', '1.7', '1.6'),
(0, 2026, 2, '2026-02-16 06:23:36.245294', 'drop unused tasks table; Expand VARCHAR columns governed by maxIDLength to VARCHAR(255)', '229846b5beb0b96f49e7a3c5fde09fa7', '1.8', '1.7'),
(0, 2026, 2, '2026-02-16 06:23:36.317637', 'add history tasks table', 'b62e4e5826967e152e00b75da42d12ea', '1.9', '1.8'),
(0, 2026, 2, '2026-02-16 06:23:36.344184', 'add storage for update records and create task_queue_user_data table', '2b0c361b0d4ab7cf09ead5566f0db520', '1.10', '1.9'),
(0, 2026, 2, '2026-02-16 06:23:36.388451', 'add queues and queue_messages tables', '790ad04897813446f2953f5bd174ad9e', '1.11', '1.10'),
(0, 2026, 2, '2026-02-16 06:23:36.408897', 'add storage for Nexus incoming service records and create nexus_incoming_services and nexus_incoming_services_partition_status tables', '9b5f3ec29f85d5feb0bdfcf234e1d781', '1.12', '1.11'),
(0, 2026, 2, '2026-02-16 06:23:36.556563', 'Replace nexus_incoming_services and nexus_incoming_services_partition_status tables with nexus_endpoints and nexus_endpoints_partition_status tables', '98943ae8910b30d83337bdb22c42abc8', '1.13', '1.12'),
(0, 2026, 2, '2026-02-16 06:23:36.562440', 'Add new start_time column', '73c44a9c2f03f5f55cf02aab0da41ec3', '1.14', '1.13'),
(0, 2026, 2, '2026-02-16 06:23:36.567014', 'Add new column `data` to current_executions table', '93e0f49ed5dd9cfa4d45b70e7bac6999', '1.15', '1.14'),
(0, 2026, 2, '2026-02-16 06:23:36.579355', 'Fix data_encoding column in current_executions table', '476336154fc93f6df4e69eb47979c991', '1.16', '1.15'),
(0, 2026, 2, '2026-02-16 06:23:36.601008', 'Add new chasm_node_maps table', '86b90742573de5574e618fb3bd6ae804', '1.17', '1.16'),
(0, 2026, 2, '2026-02-16 06:23:36.640365', 'Adds tasks_v2 table for fairness tasks', 'ebe4dee3a157b26d2c4a1af88794586b', '1.18', '1.17');
EOF

echo "--- 5. [Visibility DB] spot_visibility 버전 정보 주입 (v12.0) ---"
# Visibility는 복잡한 히스토리 없이 기본 12.0으로 설정
psql -h $RDSHOST -U $DB_USER -d spot_visibility <<EOF
CREATE TABLE schema_version (
    version_partition INTEGER NOT NULL,
    prev_version VARCHAR(255),
    curr_version VARCHAR(255),
    min_compatible_version VARCHAR(255),
    creation_time TIMESTAMP,
    PRIMARY KEY (version_partition, curr_version)
);

CREATE TABLE schema_update_history (
    version_partition INTEGER NOT NULL,
    version__history_id VARCHAR(255) NOT NULL,
    prev_version VARCHAR(255),
    curr_version VARCHAR(255),
    description VARCHAR(255),
    manifest_md5 VARCHAR(255),
    creation_time TIMESTAMP,
    PRIMARY KEY (version_partition, version__history_id)
);

INSERT INTO schema_version (version_partition, prev_version, curr_version, min_compatible_version, creation_time)
VALUES (0, NULL, '12.0', '12.0', NOW());
EOF

echo "--- ✅ 모든 작업이 완료되었습니다! ---"