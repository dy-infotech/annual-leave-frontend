import 'dart:convert';
import 'dart:io';

/// test/fixtures/ 아래의 파일 내용을 문자열로 읽는다.
String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

/// fixture 파일을 JSON 객체로 읽는다.
Map<String, dynamic> fixtureJson(String name) =>
    json.decode(fixture(name)) as Map<String, dynamic>;

/// fixture 파일을 JSON 배열로 읽는다.
List<dynamic> fixtureJsonList(String name) =>
    json.decode(fixture(name)) as List<dynamic>;
