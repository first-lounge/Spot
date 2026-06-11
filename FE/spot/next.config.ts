import type {NextConfig} from "next";

const nextConfig: NextConfig = {
  // 워크스페이스 루트 오추론 방지 (상위 경로에 한글이 있으면 Turbopack이 패닉)
  turbopack: {
    root: __dirname,
  },
  async rewrites() {
    // 배포 환경에서는 API_URL 환경변수로 게이트웨이 주소 지정
    // 로컬 docker-compose 백엔드 사용 시 아래 줄로 교체
    // const apiUrl = process.env.API_URL ?? 'http://localhost:8080';
    // 미니PC k8s 백엔드
    const apiUrl = process.env.API_URL ?? 'http://www.spot';
    return [
      {
        source: '/api/:path*',
        destination: `${apiUrl}/api/:path*`,
      },
    ];
  },
};

export default nextConfig;
