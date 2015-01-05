import 'dart:io';

import 'package:binary_interop/binary_interop.dart';
import 'package:caller_info/caller_info.dart';
import 'package:path/path.dart' as pathos;
import 'package:unittest/unittest.dart';

final String _rootDirectory = _getRootDirectory();

void main() {
  group("Test function calls.", () {
    var needCompile = true;
    if (needCompile) {
      print("Compiling 'test.c'...");
      if (_compile() != 0) {
        print("Cannot compile.");
        exit(-1);
      }

      print("Compiled.");
    }

    String filename;
    switch (Platform.operatingSystem) {
      case "android":
      case "linux":
        filename = pathos.join(_rootDirectory, "test", "libtest.so");
        break;
      case "macos":
        filename = pathos.join(_rootDirectory, "test", "libtest.mylib");
        break;
      case "windows":
        filename = pathos.join(_rootDirectory, "test", "test.dll");
        break;
      default:
        print("Unsupported operating system ${Platform.operatingSystem}.");
        exit(-1);
        break;
    }

    var lib = DynamicLibrary.load(filename);
    if (lib == null) {
      print("Cannot load '$filename'");
      exit(-1);
    }

    var types = new BinaryTypes();
    var helper = new BinaryTypeHelper(types);
    final CHAR = types["char"];
    final DOUBLE = types["double"];
    final FLOAT = types["float"];
    final INT = types["int"];
    final PCHAR = types["char*"];
    final SIZE_T = types["size_t"];
    final VA_LIST = types["..."];
    final VOID = types["void"];

    types["S0"] = helper.declareStruct("_S0", {
      "cp1": "char*"
    });

    var S0 = types["S0"];

    types["S1"] = helper.declareStruct("_S1", {
      "c1": "char",
      "i1": "int",
      "s1": S0
    });

    var S1 = types["S1"];

    var PS0 = types["S0*"];
    var PS1 = types["S1*"];

    test("Return int, parameters [void].", () {
      lib.function("sizeof_S1", INT, []);
      var result = lib.invokeEx("sizeof_S1", []);
      expect(result, S1.size);
    });

    test("Return void, parameters [void].", () {
      lib.function("test_void_void", VOID, []);
      var result = lib.invokeEx("test_void_void", []);
      expect(result, null);
    });

    test("Return struct, parameters [struct].", () {
      lib.function("test_S1_S1", S1, [S1]);
      var s1 = S1.defaultValue;
      s1["c1"] = 100;
      s1["i1"] = 200;
      var result = lib.invokeEx("test_S1_S1", [s1]);
      expect(result["c1"], 101);
      expect(result["i1"], 201);
    });

    test("Return void, parameters [struct, char*].", () {
      lib.function("test_void_pS1", VOID, [PS1, PCHAR]);
      var s1 = S1.alloc(const {});
      s1["c1"].value = 100;
      s1["i1"].value = 200;
      var hello = "Hello";
      var ca = helper.allocString(hello);
      var result = lib.invokeEx("test_void_pS1", [~s1, ~ca]);
      expect(result, null);
      expect(s1["c1"].value, 101);
      expect(s1["i1"].value, 201);
      var str2 = s1["s1"]["cp1"].value;
      var str = helper.readString(str2);
      expect(str, hello);
    });

    test("Variadic function.", () {
      DynamicLibrary stdlib;
      String SNPRINTF = "snprintf";
      switch (Platform.operatingSystem) {
        case "android":
        case "linux":
          stdlib = DynamicLibrary.load("libc.so.6");
          break;
        case "macos":
          stdlib = DynamicLibrary.load("libSystem.dylib");
          break;
        case "windows":
          stdlib = DynamicLibrary.load("msvcr100.dll");
          SNPRINTF = "_sprintf_p";
          break;
      }

      expect(stdlib == null, false, reason: "Loading stdlib");
      expect(stdlib.symbol(SNPRINTF) == 0, false, reason: "Symbol $SNPRINTF not found in ${stdlib.filename}");
      switch (Platform.operatingSystem) {
        case "android":
        case "linux":
        case "macos":
          stdlib.function(SNPRINTF, INT, [PCHAR, SIZE_T, PCHAR, VA_LIST]);
          break;
        case "windows":
          stdlib.function(SNPRINTF, INT, [PCHAR, SIZE_T, PCHAR, VA_LIST]);
          break;
      }

      int length;
      String formatted;
      var bufsize = 500;
      var buffer = CHAR.array(bufsize).alloc(const []);
      for (var i = 0; i < 2; i++) {
        var hello = helper.allocString("Hello %s");
        var world = helper.allocString("World");
        switch (i) {
          case 0:
            length = stdlib.invokeEx(SNPRINTF, [~buffer, bufsize, ~hello, ~world], [PCHAR]);
            break;
          case 1:
            length = stdlib.invoke(SNPRINTF, [~buffer, bufsize, ~hello, ~world]);
            break;
          case 2:
            length = stdlib.invoke(SNPRINTF, [~buffer, bufsize, "Hello %s", "World"]);
            break;
        }

        formatted = helper.readString(~buffer);
        expect(formatted, "Hello World", reason: "Hello World");
      }

      //
      for (var i = 0; i < 2; i++) {
        var hello = helper.allocString("Hello %i");
        switch (i) {
          case 0:
            length = stdlib.invokeEx(SNPRINTF, [~buffer, bufsize, ~hello, 42], [INT]);
            break;
          case 1:
            length = stdlib.invoke(SNPRINTF, [~buffer, bufsize, ~hello, 42]);
            break;
          case 2:
            length = stdlib.invoke(SNPRINTF, [~buffer, bufsize, "Hello %i", 42]);
            break;
        }

        formatted = helper.readString(~buffer);
        expect(formatted, "Hello 42", reason: "Hello 42");
      }

      //
      for (var i = 0; i < 2; i++) {
        var hello = helper.allocString("Hello %lf");
        switch (i) {
          case 0:
            length = stdlib.invokeEx(SNPRINTF, [~buffer, bufsize, ~hello, 42.0], [DOUBLE]);
            break;
          case 1:
            length = stdlib.invoke(SNPRINTF, [~buffer, bufsize, ~hello, 42.0]);
            break;
          case 2:
            length = stdlib.invoke(SNPRINTF, [~buffer, bufsize, "Hello %lf", 42.0]);
            break;
        }

        formatted = helper.readString(~buffer);
        expect(formatted, "Hello 42.000000", reason: "Hello 42.000000");
      }

      //
      for (var i = 0; i < 2; i++) {
        var hello = helper.allocString("Hello %i %lf");
        switch (i) {
          case 0:
            length = stdlib.invokeEx(SNPRINTF, [~buffer, bufsize, ~hello, 42, 42.0], [INT, DOUBLE]);
            break;
          case 1:
            length = stdlib.invoke(SNPRINTF, [~buffer, bufsize, ~hello, 42, 42.0]);
            break;
          case 2:
            length = stdlib.invoke(SNPRINTF, [~buffer, bufsize, "Hello %i %lf", 42, 42.0]);
            break;
        }

        formatted = helper.readString(~buffer);
        expect(formatted, "Hello 42 42.000000", reason: "Hello 42 42.000000");
      }
    });
  });
}

String _getRootDirectory() {
  var ci = new CallerInfo();
  var script = ci.file.toFilePath();
  var path = pathos.dirname(script);
  return pathos.dirname(path);
}

int _compile() {
  var arguments = <String>["--enable_async"];
  var path = pathos.join(_rootDirectory, "test", "compile.dart");
  arguments.add(path);
  var result = Process.runSync("dart", arguments);
  if (result.exitCode != 0) {
    if (result.stderr != null) {
      print(result.stderr);
    }

    if (result.stdout != null) {
      print(result.stdout);
    }
  }

  return result.exitCode;
}
