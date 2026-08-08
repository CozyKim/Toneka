[English](README.md) | [한국어](README.ko.md)

# Toneka

macOS 시스템 오디오 이퀄라이저. Toneka는 Mac이 재생 중인 소리를 Core Audio
프로세스 탭으로 받아 효과를 적용한 뒤, 선택한 출력 장치로 다시 내보낸다.
설치할 오디오 드라이버가 없다.

Toneka는 [eqMac](https://github.com/bitgapp/eqMac)에서 갈라져 나온 독립
프로젝트다. eqMac 제작자와는 아무런 제휴 관계가 없고, 그쪽의 보증이나 지원을
받지도 않는다 — [감사의 말](#감사의-말)과 [NOTICE](NOTICE)를 참고할 것.

앱의 인터페이스는 한국어다.

## 기능

- **드라이버 없음.** 시스템 오디오를 Core Audio 프로세스 탭으로 받는다. 탭과
  출력 장치는 Toneka가 실행 중일 때만 존재하는 비공개 집합 장치 안에서 하나로
  묶이므로, 캡처와 재생이 같은 클럭을 쓴다.
- **출력 선택.** 처리된 소리를 어느 장치로 내보낼지 고른다.
- **볼륨.** 음량, 음소거, 좌우 밸런스, 그리고 이득을 기준치 위로 올리는 증폭.
  출력 장치마다 음량을 따로 기억한다.
- **기본 이퀄라이저.** 저음·중음·고음, 프리셋 지원.
- **고급 이퀄라이저.** 32 Hz부터 16 kHz까지 고정된 10밴드, 프리셋 지원. 직접
  만들어 저장하고 다시 지울 수 있다.
- **스펙트럼 분석기.** 고급 이퀄라이저 뒤로 실시간 스펙트럼과 현재 응답 곡선을
  그린다.
- **설정.** 로그인 시 실행, 항상 위에, 메뉴 막대와 Dock 아이콘, 노브 조작
  방식(끌기 또는 돌리기), 겉모습 선택.

## 요구 사항

실행하려면:

- macOS 14.2 이상. Toneka는 Core Audio 프로세스 탭 API 위에 만들어졌고, 그
  이전 macOS에는 이 API가 없다.
- 시스템 설정 > 개인정보 보호 및 보안에서 허용하는 오디오 녹음 권한. 이유는
  [자주 묻는 질문](#자주-묻는-질문)에 있다.

빌드하려면:

- Xcode, 그리고 네이티브 의존성을 위한 [CocoaPods](https://cocoapods.org)
- Node 24.18.1. `.mise.toml`에 고정되어 있으며 [mise](https://mise.jdx.dev)로
  설치하는 것이 가장 간단하다.
- Yarn v1

## 빌드

미리 빌드된 배포본은 없다. 직접 빌드한다.

```bash
git clone https://github.com/CozyKim/Toneka.git
cd Toneka
(cd native && pod install)
(cd ui && yarn)
scripts/build-local.sh
```

`scripts/build-local.sh`는 웹 인터페이스를 빌드하고,
`native/Toneka.xcworkspace`의 Release 구성을 빌드한 뒤 결과물을
`/Applications/Toneka Local.app`으로 복사한다. 이 빌드는 임시(ad-hoc)
서명되고 번들 식별자로 `io.github.cozykim.toneka.local`을 쓰므로, 다른 빌드와
충돌하지 않고 자기 설정과 권한을 따로 갖는다. `--no-install`을 넘기면
`/Applications`에 아무것도 복사하지 않고 빌드만 한다.

개발할 때는 `scripts/run-debug.sh`가 Debug 구성을 빌드해 실행하고 로그를
stdout으로 내보낸다. Ctrl-C로 종료한다. 번들 식별자는
`io.github.cozykim.toneka.debug`로, 이 역시 설치된 것과 분리되어 있다. `ui/`
아래를 고쳤다면 `--ui`를 넘긴다 — 인터페이스는 zip으로 앱 안에 들어가므로
다시 빌드하고 풀어 둔 사본을 지워야 한다.

## 사용법

Toneka를 연다. 처음 실행하면 macOS가 시스템 오디오 녹음 권한을 묻는다. 이
권한이 없으면 Toneka는 아무것도 처리할 수 없다. 창을 닫아 버렸다면 시스템 설정
> 개인정보 보호 및 보안에서 허용한 뒤 앱을 다시 실행한다.

왼쪽 위 토글이 처리를 켜고 끈다. 그 아래에서 출력 장치를 고르고, 음량을
맞추고, 기본과 고급 이퀄라이저를 오간다. 프리셋은 이퀄라이저 위쪽 줄에서
고르며 거기서 저장하고 지울 수 있다. 톱니바퀴는 설정을 열고, 아래쪽 버튼은
이 문서의 자주 묻는 질문을 열거나 앱을 종료한다.

## 자주 묻는 질문

**Toneka는 오디오 드라이버를 설치하나?**
아니다. macOS 14.2가 도입한 Core Audio 프로세스 탭 API를 쓴다. 앱 번들과
Toneka 자신의 설정 바깥에는 아무것도 쓰지 않는다. Toneka가 갈라져 나온 eqMac은
`/Library/Audio/Plug-Ins/HAL`에 설치되는 HAL 플러그인을 썼지만, 그 드라이버는
없앴다.

**왜 오디오 녹음 권한을 요구하나?**
프로세스 탭은 다른 앱이 재생하는 소리를 읽는 기능이고, macOS는 이를 녹음으로
분류한다. Toneka는 시스템 출력 스트림을 읽는 데에만 이 권한을 쓴다. 권한이
없으면 처리할 소리 자체가 없다.

**Toneka가 오디오 장치를 남기나?**
아니다. Toneka가 만드는 집합 장치는 실행 중인 프로세스에만 보이는 비공개
장치이고 앱이 종료될 때 함께 사라진다. Audio MIDI 설정에 나타나지 않으므로
거기서 정리할 것도 없다.

**Toneka는 자동으로 업데이트되나?**
아니다. 업데이터가 없고, 앱이 외부로 연결하지 않는다. 새 버전으로 옮기려면 이
저장소를 받아 다시 빌드한다.

**이게 eqMac인가? eqMac 제작자에게 물어봐도 되나?**
아니고, 그러지 말 것. Toneka는 eqMac과 이력을 공유할 뿐인 별개의
프로젝트다. Toneka의 문제는
[이 저장소의 이슈](https://github.com/CozyKim/Toneka/issues)에 남긴다.

## 삭제

1. Toneka를 종료한다.
2. 앱을 지운다 — `/Applications/Toneka Local.app`, 또는 빌드를 둔 곳.
3. 저장된 데이터를 지운다.

   ```bash
   rm -rf ~/Library/Application\ Support/io.github.cozykim.toneka*
   defaults delete io.github.cozykim.toneka.local
   ```

   `defaults` 줄은 저장한 프리셋, 음량, 설정을 지운다. 디버그 빌드도 돌렸다면
   `io.github.cozykim.toneka.debug`에 대해서도 같은 명령을 실행한다.
4. "로그인 시 실행"을 켰다면 시스템 설정 > 일반 > 로그인 항목에 남은 항목이
   있는지 확인하고 지운다.
5. 원한다면 시스템 설정 > 개인정보 보호 및 보안에서 오디오 녹음 권한을
   회수한다.

지울 드라이버도, 커널 확장도, 백그라운드 서비스도 없고, Audio MIDI 설정에
남는 오디오 장치도 없다.

## 기여

빌드와 디버그 방법은 [CONTRIBUTING.md](CONTRIBUTING.md)에, 행동 강령은
[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)에 있다. 보안 문제는 공개 이슈 대신
[SECURITY.md](SECURITY.md)의 절차를 따른다.

Toneka는 한 사람이 취미로 관리하는 프로젝트이므로 답이 늦을 수 있다.

## 감사의 말

Toneka는 [Roman Kisil](https://github.com/nodeful)과 Bitgapp이 만든
[eqMac](https://github.com/bitgapp/eqMac)(Copyright 2017-2021)에서 갈라져 나온
하드 포크이며, Apache License 2.0에 따라 그 저작물을 사용한다. 오디오
파이프라인, 상태 관리, 네이티브 앱의 상당 부분은 여전히 그 작업에서 유래한다.

[NOTICE](NOTICE)에 파생 사실과 원저작물에 가한 변경 내역을 기록해 두었다.

## 라이선스

[Apache License, Version 2.0](LICENSE).
