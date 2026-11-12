/// 한글이 단어 중간에서 줄바꿈되지 않게 글자 사이를 이어 붙인다.
String keepWords(String text) => text.split(' ').map(_join).join(' ');

String _join(String word) => word.runes.map(String.fromCharCode).join('‍');
