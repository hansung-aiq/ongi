class AppConfig {
  AppConfig._();

  /// 폰이면 ws://<노트북 IP>:8765, 진짜 보드면 ws://<보드 IP>:8765로 바꾼다.
  static const boardWsUrl = 'ws://10.0.2.2:8765';

  /// 폰이면 http://<노트북 IP>:8000, 진짜 서버면 그 서버 주소로 바꾼다.
  static const serverUrl = 'http://10.0.2.2:8000';

  /// 시연용 데이터
  static const familyId = 1;

  /// 첫 설정(2-1) 전에 쓰는 자녀 이름. 문장 속 이름은 ParentProfile이 만든다.
  static const childName = '민준';
  static const momTitle = '엄마';
  static const dadTitle = '아빠';

  /// 첫 설정(2-1) 전에 쓰는 메시지 작성자 (mom / dad).
  /// 2-1이나 3-6에서 엄마·아빠를 고르면 기기에 저장한 값을 쓴다.
  static const parentAuthor = 'mom';

  static String parentTitle(String author) =>
      author == 'dad' ? dadTitle : momTitle;
}
