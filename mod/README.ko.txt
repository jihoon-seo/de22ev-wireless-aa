de22ev-wireless-aa 1.0.2 (HMG-API 모드) - DE22EV.KOR V039 260902 전용

무선 Android Auto 용 차량 AP 를 시동 ON 때마다 준비해 둡니다.
- 차량 AA 앱이 폰에 알려주는 이 차의 프로젝션용 SSID/암호(각 차량에 저장된 ConnectivitySSID/
  ConnectivityPSK)로 AP(hostapd)가 방송되게 맞춥니다. 값은 차량에서 읽으며 모드에 들어 있지 않습니다.
  (핫스팟 설정 화면의 이름/암호도 같은 값이 됩니다.)
- 무선 프로젝션 AP(연결 모드)를 켭니다.
- 차량 AA 앱을 재시작하지 않습니다. 콜드 부팅 직후에는 폰 BT 를 껐다 켜면 무선 AA 가 붙습니다.
- 시동을 끄면 AP 를 끄고, 시동이 꺼진 동안은 켜지 않습니다.
- 차량 Wi-Fi 클라이언트(Wi-Fi 탭)나 일반 핫스팟을 켜 둔 경우에는 건드리지 않습니다.

로그: /data/hmgapi/logs/de22ev-wireless-aa/waad.log
원래 자격증명 백업: /data/hmgapi/run/de22ev-wireless-aa/waad/credentials.bak
