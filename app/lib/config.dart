class AppConfig {
  AppConfig._();

  /// 폰이면 ws://<노트북 IP>:8765, 진짜 보드면 ws://<보드 IP>:8765로 바꾼다.
  static const boardWsUrl = 'ws://10.0.2.2:8765';

  /// 폰이면 http://<노트북 IP>:8000, 진짜 서버면 그 서버 주소로 바꾼다.
  static const serverUrl = 'http://10.0.2.2:8000';

  /// 시연용 데이터
  static const familyId = 1;
  static const childName = '민준';
  static const childCalled = '민준아';

  /// 부모 화면 문장에 쓰는 이름
  static const childNickname = '민준이';
  static const momTitle = '엄마';
  static const dadTitle = '아빠';

  /// 부모 화면에서 저장하는 메시지의 작성자 (mom / dad).
  /// 부모 온보딩에서 엄마·아빠를 고르게 되면 그 값으로 바꾼다.
  static const parentAuthor = 'mom';

  static String parentTitle(String author) =>
      author == 'dad' ? dadTitle : momTitle;
}
