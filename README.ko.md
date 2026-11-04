# de22ev-wireless-aa

[English](README.md)

Gen5W 헤드유닛의 무선 프로젝션 AP를 시동 ON 때마다 **무선 Android Auto**용으로 준비해 두는
[HMG-API](https://github.com/VysseCodes/HMG-API) 모드입니다.

> **시험한 차량은 한 대뿐입니다:** 펌웨어 `DE22EV.KOR.0000.V039.001.260902`
> (모델 DE22EV, 국내, Android 4.4.2, tcc897x) 기아 헤드유닛. 다른 차량에는 설치되지 않습니다.
> 비공식 프로젝트입니다. [면책](#면책)을 읽어 주세요.

## 왜 필요한가

이 차에서는 폰이 블루투스 협상을 마쳐도 무선 Android Auto가 붙지 않았습니다. 원인은 세 가지였습니다.

1. **자격증명이 두 벌입니다.** 차량 AP 설정에는 핫스팟용(`SSID`/`preSharedKey`)과
   프로젝션용(`ConnectivitySSID`/`ConnectivityPSK`)이 따로 있습니다. 차량 AA 앱은 폰에 프로젝션용을
   알려 주지만 AP(hostapd)는 핫스팟용으로 켜집니다. 폰은 없는 네트워크를 찾다가 약 36초 뒤 포기합니다.
2. **프로젝션 AP가 꺼져 있습니다.** WifiService는 `wifi_ap_on=1`일 때만 부팅 시 AP를 켜는데,
   순정 종료 과정이 `wifi_ap_on=0`을 저장합니다.
3. **부팅 타이밍.** 폰과 차량 AA 앱의 협상이 부팅 약 2초 뒤, 폰 프로젝션 서비스가 뜨기 전에
   일어나서 그 협상은 버려집니다. 다음 협상(예: 폰 BT를 껐다 켤 때)은 정상입니다.

## 하는 일

HMG-API가 실행·감시하는 작은 root 서비스(`waad`)가 부팅 때와, 재부팅 없이 ACC가 다시 켜질 때:

- 차량 Wi-Fi 클라이언트나 일반 핫스팟이 켜져 있으면 아무것도 하지 않습니다.
- 핫스팟용 자격증명을 **그 차의** 프로젝션용 값과 같게 맞추고, 바뀌었으면 AP를 다시 켭니다.
  값은 차량에서 읽으며 이 패키지에는 들어 있지 않습니다. 설정 화면의 핫스팟 이름/암호도 같은 값이
  되며, 원래 값은 백업됩니다.
- 무선 프로젝션 AP를 켭니다.

시동을 끄면 AP가 꺼진 것을 확인하고, 시동이 꺼진 동안에는 AP를 켜지 않습니다.
차량 AA 앱은 재시작하지 않습니다. 콜드 부팅 뒤에는 폰 블루투스를 껐다 켜면 무선 Android Auto가
붙습니다. 짧게 시동을 껐다 켜면 저절로 붙습니다.

## 필요 조건

- 헤드유닛에 NEMESIS와 [HMG-API](https://github.com/VysseCodes/HMG-API) 1.0.0-beta.5
  (HMG-API [설치 안내](https://github.com/VysseCodes/HMG-API/wiki/Installing-HMG-API) 참고).
- 무선 프로젝션과 Wi-Fi 기능(`android.hardware.wifi`, `com.hkmc.software.connectivity.androidauto_wireless`)이
  이미 켜져 있어야 합니다. 시험한 차는 출고 시 꺼져 있어서 별도 NEMESIS 패키지로 먼저 켰습니다.

## 설치

[Releases](../../releases)에서 받습니다:

| 파일 | 내용 |
|---|---|
| `de22ev-wireless-aa-<버전>.USB.zip` | NEMESIS USB 키트: USB로 설치·상태 확인·제거 |
| `de22ev-wireless-aa-<버전>.zip` | 서명된 HMG-API 모드 패키지 (HMG-API 자체 설치용) |
| `SHA256SUMS` | 두 파일의 체크섬 |

USB 키트로 설치:

1. 압축을 풀어 `NEMESIS.data`, `NEMESIS.sh`, `WAA_AA_MOD` 폴더를 USB 최상위에 놓습니다.
2. 시동을 켜고 1분쯤 기다린 뒤 USB를 꽂고 NEMESIS에서 **Yes**를 선택합니다.
3. USB의 `WAA_AA_MOD_*/STATUS.txt`가 `INSTALLED_WAAD_RUNNING`이면 정상입니다.

`WAA_AA_MOD/MODE.txt` 첫 줄로 동작을 고릅니다: `install`(기본), `status`(데몬 로그와 AP 상태를 USB로
복사), `uninstall`(모드 제거, 원래 핫스팟 이름/암호 복원, AP 끄기, `wifi_ap_on=0`).
키트 안의 `사용방법.txt` / `USAGE.en.txt`도 참고하세요.

패키지는 이 저장소의 작성자 키로 서명됩니다(uuid `3c503596-94a4-8f10-901e-d6da35861d6a`,
공개키 [`keys/author.key.pub`](keys/author.key.pub)). 이 키는 HMG-API의 신뢰 작성자 목록에 없어서
설치 기록에 경고가 남지만 설치는 진행됩니다. 업데이트는 같은 키로 서명된 것만 이전 버전 위에 설치됩니다.

## 받은 파일 검증

```
sha256sum -c SHA256SUMS
```

패키지의 `META-HMGAPI/manifest.json`에는 모든 파일의 SHA-256과 작성자 키가 있고,
`META-HMGAPI/signature`가 그 manifest를 서명합니다. `build.sh`가 만드는 HMG-API 서명 도구로 확인합니다:

```
java -cp build/hmgsign hmgapi.engine.Signing verify <압축 푼 패키지> 3c503596-94a4-8f10-901e-d6da35861d6a
```

## 차량 내부 경로

| | |
|---|---|
| 모드 | `/data/hmgapi/mods/de22ev-wireless-aa` |
| 로그 | `/data/hmgapi/logs/de22ev-wireless-aa/waad.log` |
| 자격증명 백업 | `/data/hmgapi/run/de22ev-wireless-aa/waad/credentials.bak` |

## 소스에서 빌드

```
export D8_JAR=/path/to/r8.jar          # com.android.tools.r8.D8 가 든 jar
export SIGN_KEY=/path/to/author.key    # 선택. 없으면 서명 없이 빌드
./build.sh                             # -> dist/
./tests/run-all.sh                     # PC 테스트: WaaAp, 데몬, USB 키트
```

JDK 8 이상, Python 3, curl, D8이 필요하며 Android SDK는 필요 없습니다(`WaaAp`는 숨은 Android API를
리플렉션으로 씀). 서명 도구는 고정된 커밋의 HMG-API에서 가져옵니다([`tools/hmgsign`](tools/hmgsign)).
`SIGN_KEY` 없이 빌드한 파일은 릴리스의 `META-HMGAPI/manifest.json`과 비교할 수 있습니다(서명값 자체는
서명할 때마다 달라집니다).

## 구성

| 경로 | |
|---|---|
| `mod/` | 모드: `mod.json`, `svc/waad.sh`(데몬), README |
| `src/WaaAp.java` | 데몬이 부르는 도우미(`app_process`): AP 상태, 자격증명, AP 켜기/끄기, 백업/복원 |
| `usb/` | NEMESIS USB 키트 |
| `tests/` | Android와 hmgapid를 흉내 내는 PC 테스트 |
| `tools/` | 서명 도구, 재현 가능한 zip 도우미 |
| `keys/` | 작성자 공개키와 uuid |

## 면책

개인 취미로 만든 비공식 프로젝트이며 현대자동차그룹, 기아, 현대모비스, Google과 관련이 없고 승인받지
않았습니다. Android Auto는 Google LLC의 상표입니다. 헤드유닛을 수정하면 보증을 받지 못하거나 기기가
제대로 동작하지 않을 수 있습니다. 차량 한 대, 펌웨어 하나에서만 시험했습니다. 사용에 따른 책임은
사용자에게 있으며 어떠한 보증도 없습니다([LICENSE](LICENSE)).

## 라이선스

이 저장소의 코드는 [MIT](LICENSE)입니다. `build.sh`가 서명 도구를 만들려고 받아 오는 HMG-API의
`Signing.java`, `Json.java`는 AGPL-3.0이며 이 저장소에 포함되지 않습니다.

## 감사

서비스를 실행·감시하고 서명을 검증하는 [HMG-API](https://github.com/VysseCodes/HMG-API) (VysseCodes).
