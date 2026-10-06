final allGrammars = {
  'js': javascriptGrammar,
  'console': consoleGrammar,
  'lua': luaGrammar,
  'cpp': cppGrammar,
  'python': pythonGrammar,
  'nasm': nasmGrammar,
  'armasm': armasmGrammar,
  'java': javaGrammar,
  'diff': diffGrammar,
  'go': goGrammar,
  'yaml': yamlGrammar,
};

// From https://github.com/serverpod/syntax_highlight/tree/main/grammars
final javascriptGrammar = (r'''
{
  "name": "JavaScript",
  "version": "1.0.0",
  "fileTypes": ["js", "mjs", "cjs"],
  "scopeName": "source.js",

  "foldingStartMarker": "\\{\\s*$",
  "foldingStopMarker": "^\\s*\\}",

  "patterns": [
    {
      "name": "meta.preprocessor.script.js",
      "match": "^(#!.*)$"
    },
    {
      "name": "meta.import-export.js",
      "begin": "\\b(import|export)\\b",
      "beginCaptures": {
        "0": {
          "name": "keyword.control.import.js"
        }
      },
      "end": ";",
      "endCaptures": {
        "0": {
          "name": "punctuation.terminator.js"
        }
      },
      "patterns": [
        {
          "include": "#strings"
        },
        {
          "include": "#comments"
        },
        {
          "name": "keyword.control.import.js",
          "match": "\\b(as|from)\\b"
        }
      ]
    },
    {
      "include": "#comments"
    },
    {
      "include": "#keywords"
    },
    {
      "include": "#constants-and-special-vars"
    },
    {
      "include": "#operators"
    },
    {
      "include": "#strings"
    }
  ],

  "repository": {
    "comments": {
      "patterns": [
        {
          "name": "comment.block.js",
          "begin": "/\\*",
          "end": "\\*/"
        },
        {
          "name": "comment.line.double-slash.js",
          "match": "//.*$"
        }
      ]
    },
    "keywords": {
      "patterns": [
        {
          "name": "keyword.control.js",
          "match": "\\b(if|else|for|while|do|switch|case|default|break|continue|return|throw|try|catch|finally)\\b"
        },
        {
          "name": "keyword.operator.js",
          "match": "\\b(instanceof|typeof|new|delete|in|void)\\b"
        },
        {
          "name": "storage.type.js",
          "match": "\\b(var|let|const|function|class|extends)\\b"
        },
        {
          "name": "keyword.declaration.js",
          "match": "\\b(export|import|default)\\b"
        }
      ]
    },
    "constants-and-special-vars": {
      "patterns": [
        {
          "name": "constant.language.js",
          "match": "\\b(true|false|null|undefined|NaN|Infinity)\\b"
        },
        {
          "name": "constant.numeric.js",
          "match": "\\b(0x[0-9A-Fa-f]+|[0-9]+\\.?[0-9]*(e[+-]?[0-9]+)?)\\b"
        }
      ]
    },
    "operators": {
      "patterns": [
        {
          "name": "keyword.operator.assignment.js",
          "match": "(=|\\+=|-=|\\*=|/=|%=|\\|=|&=|\\^=|<<=|>>=|>>>=)"
        },
        {
          "name": "keyword.operator.comparison.js",
          "match": "(==|!=|===|!==|<|<=|>|>=)"
        },
        {
          "name": "keyword.operator.logical.js",
          "match": "(&&|\\|\\||!)"
        },
        {
          "name": "keyword.operator.arithmetic.js",
          "match": "(-|\\+|\\*|/|%)"
        },
        {
          "name": "keyword.operator.bitwise.js",
          "match": "(\\||&|\\^|~|<<|>>|>>>)"
        }
      ]
    },
    "strings": {
      "patterns": [
        {
          "name": "string.quoted.double.js",
          "begin": "\"",
          "end": "\"",
          "patterns": [
            {
              "include": "#string-interpolation"
            }
          ]
        },
        {
          "name": "string.quoted.single.js",
          "begin": "'",
          "end": "'",
          "patterns": [
            {
              "include": "#string-interpolation"
            }
          ]
        },
        {
          "name": "string.template.js",
          "begin": "`",
          "end": "`",
          "patterns": [
            {
              "include": "#string-interpolation"
            }
          ]
        }
      ]
    },
    "string-interpolation": {
      "patterns": [
        {
          "name": "variable.parameter.js",
          "begin": "\\$\\{",
          "end": "\\}"
        }
      ]
    }
  }
}
''');

// From https://github.com/textmate/lua.tmbundle
final luaGrammar = r'''
{
    "fileTypes": [
        "lua",
        "p8",
        "rockspec"
    ],
    "firstLineMatch": "\\A#!.*?\\blua(\\d+(\\.\\d+)?)?\\b|\\A--\\s+-\\*-\\s*lua\\s*-\\*-",
    "repository": {
        "escaped_char": {
            "patterns": [
                {
                    "match": "\\\\[abfnrtvz\\\\\"'\\n]",
                    "name": "constant.character.escape.lua"
                },
                {
                    "match": "\\\\\\d{1,3}",
                    "name": "constant.character.escape.byte.lua"
                },
                {
                    "match": "\\\\x[0-9A-Fa-f][0-9A-Fa-f]",
                    "name": "constant.character.escape.byte.lua"
                },
                {
                    "match": "\\\\u\\{[0-9A-Fa-f]+\\}",
                    "name": "constant.character.escape.unicode.lua"
                },
                {
                    "match": "\\\\.",
                    "name": "invalid.illegal.character.escape.lua"
                }
            ]
        }
    },
    "keyEquivalent": "^~L",
    "uuid": "93E017CC-6F27-11D9-90EB-000D93589AF7",
    "patterns": [
        {
            "begin": "\\b(?:(local)\\s+)?(function)\\s*(?:\\s+([a-zA-Z_][a-zA-Z0-9_]*(?:([\\.:])[a-zA-Z_][a-zA-Z0-9_]*)?)\\s*)?(\\()",
            "endCaptures": {
                "0": {
                    "name": "punctuation.definition.parameters.end.lua"
                }
            },
            "end": "\\)",
            "patterns": [
                {
                    "match": "[a-zA-Z_][a-zA-Z0-9_]*",
                    "name": "variable.parameter.function.lua"
                },
                {
                    "match": ",",
                    "name": "punctuation.separator.arguments.lua"
                }
            ],
            "name": "meta.function.lua",
            "beginCaptures": {
                "3": {
                    "name": "entity.name.function.lua"
                },
                "1": {
                    "name": "storage.modifier.local.lua"
                },
                "4": {
                    "name": "punctuation.separator.parameter.lua"
                },
                "2": {
                    "name": "keyword.control.lua"
                },
                "5": {
                    "name": "punctuation.definition.parameters.begin.lua"
                }
            }
        },
        {
            "match": "(?<![\\w\\d.])0[xX][0-9A-Fa-f]+(?![pPeE.0-9])",
            "name": "constant.numeric.integer.hexadecimal.lua"
        },
        {
            "match": "(?<![\\w\\d.])0[xX][0-9A-Fa-f]+(\\.[0-9A-Fa-f]+)?([eE]-?\\d*)?([pP][-+]\\d+)?",
            "name": "constant.numeric.float.hexadecimal.lua"
        },
        {
            "match": "(?<![\\w\\d.])\\d+(?![pPeE.0-9])",
            "name": "constant.numeric.integer.lua"
        },
        {
            "match": "(?<![\\w\\d.])\\d+(\\.\\d+)?([eE]-?\\d*)?",
            "name": "constant.numeric.float.lua"
        },
        {
            "begin": "'",
            "endCaptures": {
                "0": {
                    "name": "punctuation.definition.string.end.lua"
                }
            },
            "end": "'",
            "patterns": [
                {
                    "include": "#escaped_char"
                }
            ],
            "name": "string.quoted.single.lua",
            "beginCaptures": {
                "0": {
                    "name": "punctuation.definition.string.begin.lua"
                }
            }
        },
        {
            "begin": "\"",
            "endCaptures": {
                "0": {
                    "name": "punctuation.definition.string.end.lua"
                }
            },
            "end": "\"",
            "patterns": [
                {
                    "include": "#escaped_char"
                }
            ],
            "name": "string.quoted.double.lua",
            "beginCaptures": {
                "0": {
                    "name": "punctuation.definition.string.begin.lua"
                }
            }
        },
        {
            "begin": "(?<=\\.cdef)\\s*(\\[(=*)\\[)",
            "endCaptures": {
                "0": {
                    "name": "string.quoted.other.multiline.lua"
                },
                "1": {
                    "name": "punctuation.definition.string.end.lua"
                }
            },
            "end": "(\\]\\2\\])",
            "patterns": [
                {
                    "include": "source.c"
                }
            ],
            "contentName": "meta.embedded.lua",
            "beginCaptures": {
                "0": {
                    "name": "string.quoted.other.multiline.lua"
                },
                "1": {
                    "name": "punctuation.definition.string.begin.lua"
                }
            }
        },
        {
            "begin": "(?<!--)\\[(=*)\\[",
            "endCaptures": {
                "0": {
                    "name": "punctuation.definition.string.end.lua"
                }
            },
            "end": "\\]\\1\\]",
            "name": "string.quoted.other.multiline.lua",
            "beginCaptures": {
                "0": {
                    "name": "punctuation.definition.string.begin.lua"
                }
            }
        },
        {
            "match": "\\A(#!).*$\\n?",
            "name": "comment.line.shebang.lua",
            "captures": {
                "1": {
                    "name": "punctuation.definition.comment.lua"
                }
            }
        },
        {
            "begin": "(^[ \\t]+)?(?=--)",
            "endCaptures": {
                "1": {
                    "name": "punctuation.whitespace.comment.trailing.lua"
                }
            },
            "end": "(?!\\G)((?!^)[ \\t]+\\n)?",
            "patterns": [
                {
                    "begin": "--\\[(=*)\\[",
                    "endCaptures": {
                        "0": {
                            "name": "punctuation.definition.comment.end.lua"
                        }
                    },
                    "end": "\\]\\1\\]",
                    "name": "comment.block.lua",
                    "beginCaptures": {
                        "0": {
                            "name": "punctuation.definition.comment.begin.lua"
                        }
                    }
                },
                {
                    "begin": "--",
                    "end": "\\n",
                    "name": "comment.line.double-dash.lua",
                    "beginCaptures": {
                        "0": {
                            "name": "punctuation.definition.comment.lua"
                        }
                    }
                }
            ],
            "beginCaptures": {
                "1": {
                    "name": "punctuation.whitespace.comment.leading.lua"
                }
            }
        },
        {
            "match": "\\b(goto)\\s+([a-zA-Z_][a-zA-Z0-9_]*)",
            "captures": {
                "1": {
                    "name": "keyword.control.goto.lua"
                },
                "2": {
                    "name": "constant.other.placeholder.lua"
                }
            }
        },
        {
            "match": "(::)[a-zA-Z_][a-zA-Z0-9_]*(::)",
            "name": "constant.other.placeholder.lua",
            "captures": {
                "1": {
                    "name": "punctuation.definition.label.begin.lua"
                },
                "2": {
                    "name": "punctuation.definition.label.end.lua"
                }
            }
        },
        {
            "match": "\\b(break|do|else|for|if|elseif|goto|return|then|repeat|while|until|end|function|local|in)\\b",
            "name": "keyword.control.lua"
        },
        {
            "match": "(?<![^.]\\.|:)\\b(false|nil|true|_G|_VERSION|math\\.(pi|huge))\\b|(?<![.])\\.{3}(?!\\.)",
            "name": "constant.language.lua"
        },
        {
            "match": "(?<![^.]\\.|:)\\b(self)\\b",
            "name": "variable.language.self.lua"
        },
        {
            "match": "(?<![^.]\\.|:)\\b(assert|collectgarbage|dofile|error|getfenv|getmetatable|ipairs|loadfile|loadstring|module|next|pairs|pcall|print|rawequal|rawget|rawset|require|select|setfenv|setmetatable|tonumber|tostring|type|unpack|xpcall)\\b(?=\\s*(?:[({\"']|\\[\\[))",
            "name": "support.function.lua"
        },
        {
            "match": "(?<![^.]\\.|:)\\b(coroutine\\.(create|resume|running|status|wrap|yield)|string\\.(byte|char|dump|find|format|gmatch|gsub|len|lower|match|rep|reverse|sub|upper)|table\\.(concat|insert|maxn|remove|sort)|math\\.(abs|acos|asin|atan2?|ceil|cosh?|deg|exp|floor|fmod|frexp|ldexp|log|log10|max|min|modf|pow|rad|random|randomseed|sinh?|sqrt|tanh?)|io\\.(close|flush|input|lines|open|output|popen|read|tmpfile|type|write)|os\\.(clock|date|difftime|execute|exit|getenv|remove|rename|setlocale|time|tmpname)|package\\.(cpath|loaded|loadlib|path|preload|seeall)|debug\\.(debug|[gs]etfenv|[gs]ethook|getinfo|[gs]etlocal|[gs]etmetatable|getregistry|[gs]etupvalue|traceback))\\b(?=\\s*(?:[({\"']|\\[\\[))",
            "name": "support.function.library.lua"
        },
        {
            "match": "\\b(and|or|not)\\b",
            "name": "keyword.operator.lua"
        },
        {
            "match": "\\b([a-zA-Z_][a-zA-Z0-9_]*)\\b(?=\\s*(?:[({\"']|\\[\\[))",
            "name": "support.function.any-method.lua"
        },
        {
            "match": "(?<=[^.]\\.|:)\\b([a-zA-Z_][a-zA-Z0-9_]*)",
            "name": "variable.other.lua"
        },
        {
            "match": "\\+|-|%|#|\\*|\\/|\\^|==?|~=|<=?|>=?|(?<!\\.)\\.{2}(?!\\.)",
            "name": "keyword.operator.lua"
        }
    ],
    "name": "Lua",
    "scopeName": "source.lua"
}''';

// From https://raw.githubusercontent.com/shikijs/textmate-grammars-themes/refs/heads/main/packages/tm-grammars/grammars/shellsession.json
final consoleGrammar = r'''
{
  "displayName": "Shell Session",
  "fileTypes": [
    "sh-session"
  ],
  "name": "shellsession",
  "patterns": [
    {
      "captures": {
        "1": {
          "name": "entity.other.prompt-prefix.shell-session"
        },
        "2": {
          "name": "punctuation.separator.prompt.shell-session"
        },
        "3": {
          "name": "source.shell"
        }
      },
      "match": "^(?:((?:\\(\\S+\\)\\s*)?(?:sh\\S*?|\\w+\\S+[:@]\\S+(?:\\s+\\S+)?|\\[\\S+?[:@]\\N+?].*?))\\s*)?([#$%>❯➜\\p{Greek}])\\s+(.*)$"
    },
    {
      "match": "^.+$",
      "name": "meta.output.shell-session"
    }
  ],
  "scopeName": "text.shell-session"
}''';

final cppGrammar = r'''
{
  "name": "C++",
  "version": "1.0.0",
  "fileTypes": ["cpp", "cc"],
  "scopeName": "source.cpp",

  "foldingStartMarker": "\\{\\s*$",
  "foldingStopMarker": "^\\s*\\}",

  "patterns": [
    {
      "name": "meta.preprocessor.script.js",
      "match": "^(#!.*)$"
    },
    {
      "include": "#comments"
    },
    {
      "include": "#keywords"
    },
    {
      "include": "#constants-and-special-vars"
    },
    {
      "include": "#operators"
    },
    {
      "include": "#strings"
    }
  ],

  "repository": {
    "comments": {
      "patterns": [
        {
          "name": "comment.block.cpp",
          "begin": "/\\*",
          "end": "\\*/"
        },
        {
          "name": "comment.line.double-slash.cpp",
          "match": "//.*$"
        }
      ]
    },
    "keywords": {
      "patterns": [
        {
          "name": "keyword.control.cpp",
          "match": "\\b(if|else|for|while|do|switch|case|default|break|continue|return|throw|try|catch|finally)\\b"
        },
        {
          "name": "keyword.operator.cpp",
          "match": "\\b(new|delete|sizeof)\\b"
        },
        {
          "name": "keyword.type.cpp",
          "match": "\\b(auto|const|void|class|struct|typedef|using|namespace|template|static)\\b"
        }
      ]
    },
    "constants-and-special-vars": {
      "patterns": [
        {
          "name": "constant.language.cpp",
          "match": "\\b(true|false|nullptr)\\b"
        },
        {
          "name": "constant.numeric.cpp",
          "match": "\\b(0x[0-9A-Fa-f]+|[0-9]+\\.?[0-9]*(e[+-]?[0-9]+)?)\\b"
        }
      ]
    },
    "operators": {
      "patterns": [
        {
          "name": "keyword.operator.assignment.cpp",
          "match": "(=|\\+=|-=|\\*=|/=|%=|\\|=|&=|\\^=|<<=|>>=|>>>=)"
        },
        {
          "name": "keyword.operator.comparison.cpp",
          "match": "(==|!=|===|!==|<|<=|>|>=)"
        },
        {
          "name": "keyword.operator.logical.cpp",
          "match": "(&&|\\|\\||!)"
        },
        {
          "name": "keyword.operator.arithmetic.cpp",
          "match": "(-|\\+|\\*|/|%)"
        },
        {
          "name": "keyword.operator.bitwise.cpp",
          "match": "(\\||&|\\^|~|<<|>>|>>>)"
        }
      ]
    },
    "strings": {
      "patterns": [
        {
          "name": "string.quoted.double.cpp",
          "begin": "\"",
          "end": "\""
        },
        {
          "name": "string.quoted.single.cpp",
          "begin": "'",
          "end": "'"
        }
      ]
    }
  }
}
''';

final nasmGrammar = r'''
{
  "name": "Nasm",
  "version": "1.0.0",
  "fileTypes": ["asm", "asm"],
  "scopeName": "source.nasm",

  "patterns": [
    {
      "include": "#comments"
    },
    {
      "include": "#keywords"
    }
  ],

  "repository": {
    "comments": {
      "patterns": [
        {
          "name": "comment.line.double-semicolon.nasm",
          "match": ";;.*$"
        }
      ]
    },
    "keywords": {
      "patterns": [
        {
          "name": "keyword.control.nasm",
          "match": "^\\s*\\w+\\b"
        }
      ]
    },
    "strings": {
      "patterns": [
        {
          "name": "string.quoted.double.cpp",
          "begin": "\"",
          "end": "\""
        },
        {
          "name": "string.quoted.single.cpp",
          "begin": "'",
          "end": "'"
        }
      ]
    }
  }
}
''';

final pythonGrammar = r"""
{
  "name": "Python",
  "version": "1.0.0",
  "fileTypes": ["py"],
  "scopeName": "source.python",
  "foldingStartMarker": "\\b(?:def|class)\\s*[^:]*:\\s*$",
  "foldingStopMarker": "^\\s*\\}",
  "patterns": [
    { "include": "#comments" },
    { "include": "#keywords" },
    { "include": "#constants-and-special-vars" },
    { "include": "#operators" },
    { "include": "#strings" }
  ],
  "repository": {
    "comments": {
      "patterns": [
        { "name": "comment.line.hash.python", "match": "#.*$" },
        { "name": "comment.block.python", "begin": "'''", "end": "'''" },
        { "name": "comment.block.python", "begin": "\"\"\"", "end": "\"\"\"" }
      ]
    },
    "keywords": {
      "patterns": [
        {
          "name": "keyword.control.python",
          "match": "\\b(?:if|else|while|for|in|break|continue|return)\\b"
        },
        {
          "name": "keyword.operator.logical.python",
          "match": "\\b(?:and|or|not)\\b"
        },
        { "name": "keyword.operator.assignment.python", "match": "=" },
        { "name": "storage.modifier.python", "match": "\\b(?:def|class)\\b" }
      ]
    },
    "constants-and-special-vars": {
      "patterns": [
        {
          "name": "constant.language.python",
          "match": "\\b(?:True|False|None)\\b"
        },
        { "name": "variable.language.python", "match": "\\b(?:self)\\b" },
        {
          "name": "constant.numeric.python",
          "match": "\\b(?:\\d+\\.?\\d*|\\.\\d+)\\b"
        }
      ]
    },
    "operators": {
      "patterns": [
        {
          "name": "keyword.operator.arithmetic.python",
          "match": "\\b(?:\\+|-|\\*|/|%|//)\\b"
        },
        {
          "name": "keyword.operator.comparison.python",
          "match": "\\b(?:==|!=|<|<=|>|>=)\\b"
        },
        {
          "name": "keyword.operator.logical.python",
          "match": "\\b(?:and|or|not)\\b"
        }
      ]
    },
    "strings": {
      "patterns": [
        {
          "name": "string.quoted.triple.double.python",
          "begin": "\"\"\"",
          "end": "\"\"\""
        },
        {
          "name": "string.quoted.triple.single.python",
          "begin": "'''",
          "end": "'''"
        },
        {
          "name": "string.quoted.double.python",
          "begin": "\"",
          "end": "\"",
          "patterns": [{ "include": "#string-escape" }]
        },
        {
          "name": "string.quoted.single.python",
          "begin": "'",
          "end": "'",
          "patterns": [{ "include": "#string-escape" }]
        }
      ]
    },
    "string-escape": {
      "patterns": [
        { "name": "constant.character.escape.python", "match": "\\\\[\"']" }
      ]
    }
  }
}
""";

final javaGrammar = r"""
{
  "name": "Java",
  "version": "1.0.0",
  "fileTypes": ["java"],
  "scopeName": "source.java",

  "foldingStartMarker": "\\{\\s*$",
  "foldingStopMarker": "^\\s*\\}",

  "patterns": [
    {
      "include": "#comments"
    },
    {
      "include": "#keywords"
    },
    {
      "include": "#constants"
    },
    {
      "include": "#strings"
    },
    {
      "include": "#numbers"
    },
    {
      "include": "#types"
    },
    {
      "include": "#annotations"
    }
  ],

  "repository": {
    "comments": {
      "patterns": [
        {
          "name": "comment.block.java",
          "begin": "/\\*",
          "end": "\\*/"
        },
        {
          "name": "comment.block.documentation.java",
          "begin": "/\\*\\*",
          "end": "\\*/",
          "patterns": [
            {
              "name": "entity.name.tag.documentation.java",
              "match": "@[a-zA-Z]+"
            }
          ]
        },
        {
          "name": "comment.line.double-slash.java",
          "match": "//.*$"
        }
      ]
    },
    "keywords": {
      "patterns": [
        {
          "name": "keyword.control.java",
          "match": "\\b(if|else|for|while|do|switch|case|break|continue|return|try|catch|finally|throw|assert)\\b"
        },
        {
          "name": "keyword.declaration.java",
          "match": "\\b(public|private|protected|static|final|abstract|synchronized|volatile|transient|native|strictfp)\\b"
        },
        {
          "name": "keyword.operator.java",
          "match": "\\b(new|instanceof)\\b"
        },
        {
          "name": "keyword.other.java",
          "match": "\\b(import|package|class|interface|enum|extends|implements|throws)\\b"
        }
      ]
    },
    "constants": {
      "patterns": [
        {
          "name": "constant.language.java",
          "match": "\\b(true|false|null)\\b"
        }
      ]
    },
    "strings": {
      "patterns": [
        {
          "name": "string.quoted.double.java",
          "begin": "\"",
          "end": "\"",
          "patterns": [
            {
              "name": "constant.character.escape.java",
              "match": "\\\\."
            }
          ]
        },
        {
          "name": "string.quoted.single.java",
          "begin": "'",
          "end": "'",
          "patterns": [
            {
              "name": "constant.character.escape.java",
              "match": "\\\\."
            }
          ]
        }
      ]
    },
    "numbers": {
      "patterns": [
        {
          "name": "constant.numeric.java",
          "match": "\\b([+-]?\\d+(\\.\\d+)?([eE][+-]?\\d+)?[fFdDlL]?)\\b"
        }
      ]
    },
    "types": {
      "patterns": [
        {
          "name": "support.type.primitive.java",
          "match": "\\b(byte|short|int|long|float|double|boolean|char|void)\\b"
        },
        {
          "name": "entity.name.type.class.java",
          "match": "\\b([A-Z][a-zA-Z0-9_]*)\\b"
        }
      ]
    },
    "annotations": {
      "patterns": [
        {
          "name": "meta.annotation.java",
          "match": "@[a-zA-Z][a-zA-Z0-9_]*"
        }
      ]
    }
  }
}""";

final diffGrammar = r"""
{
  "displayName": "Diff",
  "name": "diff",
  "patterns": [
    {
      "captures": {
        "1": {
          "name": "punctuation.definition.separator.diff"
        }
      },
      "match": "^((\\*{15})|(={67})|(-{3}))$\\n?",
      "name": "meta.separator.diff"
    },
    {
      "match": "^\\d+(,\\d+)*([acd])\\d+(,\\d+)*$\\n?",
      "name": "meta.diff.range.normal"
    },
    {
      "captures": {
        "1": {
          "name": "meta.toc-list.line-number.diff"
        }
      },
      "match": "^@@\\s*(.+?)\\s*@@($\\n?)?.*$",
      "name": "meta.diff.range.unified"
    },
    {
      "captures": {
        "3": {
          "name": "punctuation.definition.range.diff"
        },
        "4": {
          "name": "punctuation.definition.range.diff"
        },
        "6": {
          "name": "punctuation.definition.range.diff"
        },
        "7": {
          "name": "punctuation.definition.range.diff"
        }
      },
      "match": "^(((-{3}) .+ (-{4}))|((\\*{3}) .+ (\\*{4})))$\\n?",
      "name": "meta.diff.range.context"
    },
    {
      "match": "^diff --git a/.*$\\n?",
      "name": "meta.diff.header.git"
    },
    {
      "match": "^diff (-|\\S+\\s+\\S+).*$\\n?",
      "name": "meta.diff.header.command"
    },
    {
      "captures": {
        "4": {
          "name": "punctuation.definition.from-file.diff"
        },
        "6": {
          "name": "punctuation.definition.from-file.diff"
        },
        "7": {
          "name": "punctuation.definition.from-file.diff"
        }
      },
      "match": "^((((-{3}) .+)|((\\*{3}) .+))$\\n?|(={4}) .+(?= - ))",
      "name": "meta.diff.header.from-file"
    },
    {
      "captures": {
        "2": {
          "name": "punctuation.definition.to-file.diff"
        },
        "3": {
          "name": "punctuation.definition.to-file.diff"
        },
        "4": {
          "name": "punctuation.definition.to-file.diff"
        }
      },
      "match": "(^(\\+{3}) .+$\\n?| (-) .* (={4})$\\n?)",
      "name": "meta.diff.header.to-file"
    },
    {
      "captures": {
        "3": {
          "name": "punctuation.definition.inserted.diff"
        },
        "6": {
          "name": "punctuation.definition.inserted.diff"
        }
      },
      "match": "^(((>)( .*)?)|((\\+).*))$\\n?",
      "name": "markup.inserted.diff"
    },
    {
      "captures": {
        "1": {
          "name": "punctuation.definition.changed.diff"
        }
      },
      "match": "^(!).*$\\n?",
      "name": "markup.changed.diff"
    },
    {
      "captures": {
        "3": {
          "name": "punctuation.definition.deleted.diff"
        },
        "6": {
          "name": "punctuation.definition.deleted.diff"
        }
      },
      "match": "^(((<)( .*)?)|((-).*))$\\n?",
      "name": "markup.deleted.diff"
    },
    {
      "begin": "^(#)",
      "captures": {
        "1": {
          "name": "punctuation.definition.comment.diff"
        }
      },
      "end": "\\n",
      "name": "comment.line.number-sign.diff"
    },
    {
      "match": "^index [0-9a-f]{7,40}\\.\\.[0-9a-f]{7,40}.*$\\n?",
      "name": "meta.diff.index.git"
    },
    {
      "captures": {
        "1": {
          "name": "punctuation.separator.key-value.diff"
        },
        "2": {
          "name": "meta.toc-list.file-name.diff"
        }
      },
      "match": "^Index(:) (.+)$\\n?",
      "name": "meta.diff.index"
    },
    {
      "match": "^Only in .*: .*$\\n?",
      "name": "meta.diff.only-in"
    }
  ],
  "scopeName": "source.diff"
}
""";

final goGrammar = r"""
{
  "name": "Go",
  "version": "1.0.0",
  "fileTypes": ["go"],
  "scopeName": "source.go",
  "foldingStartMarker": "\\{\\s*$",
  "foldingStopMarker": "^\\s*\\}",
  "patterns": [
    {
      "name": "meta.package.go",
      "begin": "^\\s*package\\b",
      "end": "$",
      "patterns": [
        {
          "include": "#identifier"
        }
      ]
    },
    {
      "name": "meta.import.go",
      "begin": "^\\s*import\\b",
      "end": "(?=^[^\\s]|\\Z)",
      "patterns": [
        {
          "name": "string.quoted.double.go",
          "match": "\"[^\"]*\""
        },
        {
          "include": "#identifier"
        }
      ]
    },
    {
      "include": "#comments"
    },
    {
      "include": "#keywords"
    },
    {
      "include": "#constants"
    },
    {
      "include": "#operators"
    },
    {
      "include": "#strings"
    },
    {
      "include": "#punctuation"
    },
    {
      "include": "#functions"
    }
  ],
  "repository": {
    "comments": {
      "patterns": [
        {
          "name": "comment.line.double-slash.go",
          "match": "//.*$"
        },
        {
          "name": "comment.block.go",
          "begin": "/\\*",
          "end": "\\*/"
        }
      ]
    },
    "keywords": {
      "patterns": [
        {
          "name": "keyword.control.go",
          "match": "\\b(if|else|for|range|switch|case|select|break|continue|fallthrough|return|go|defer|goto|default)\\b"
        },
        {
          "name": "keyword.declaration.go",
          "match": "\\b(var|const|type|struct|interface|func|package|import|map|chan)\\b"
        },
        {
          "name": "keyword.storage.go",
          "match": "\\b(bool|byte|complex64|complex128|error|float32|float64|int|int8|int16|int32|int64|rune|string|uint|uint8|uint16|uint32|uint64|uintptr)\\b"
        }
      ]
    },
    "constants": {
      "patterns": [
        {
          "name": "constant.language.go",
          "match": "\\b(true|false|iota|nil)\\b"
        },
        {
          "name": "constant.numeric.go",
          "match": "\\b\\d+(_\\d+)*\\.?\\d*([eE][+-]?\\d+)?\\b"
        },
        {
          "name": "constant.character.escape.go",
          "match": "\\\\."
        }
      ]
    },
    "operators": {
      "patterns": [
        {
          "name": "keyword.operator.go",
          "match": "\\+\\+|--|==|!=|<=|>=|&&|\\|\\||<<|>>|&\\^|\\+=|-=|\\*=|/=|%="
        },
        {
          "name": "keyword.operator.assignment.go",
          "match": "="
        },
        {
          "name": "keyword.operator.arithmetic.go",
          "match": "[+\\-*/%]"
        },
        {
          "name": "keyword.operator.bitwise.go",
          "match": "[&|^]"
        },
        {
          "name": "keyword.operator.logical.go",
          "match": "&&|\\|\\||!"
        }
      ]
    },
    "strings": {
      "patterns": [
        {
          "name": "string.quoted.double.go",
          "begin": "\"",
          "end": "\"",
          "patterns": [
            {
              "name": "constant.character.escape.go",
              "match": "\\\\."
            }
          ]
        },
        {
          "name": "string.quoted.raw.go",
          "begin": "`",
          "end": "`"
        }
      ]
    },
    "punctuation": {
      "patterns": [
        {
          "name": "punctuation.separator.go",
          "match": "[,;]"
        },
        {
          "name": "punctuation.bracket.go",
          "match": "[\\[\\](){}]"
        }
      ]
    },
    "functions": {
      "patterns": [
        {
          "name": "meta.function.go",
          "begin": "\\bfunc\\b",
          "end": "(?=\\{)",
          "patterns": [
            {
              "include": "#identifier"
            }
          ]
        }
      ]
    },
    "identifier": {
      "patterns": [
        {
          "name": "variable.other.go",
          "match": "\\b[a-zA-Z_][a-zA-Z0-9_]*\\b"
        }
      ]
    }
  }
}
""";

final yamlGrammar = r"""
{
    "name": "YAML",
    "fileTypes": ["yaml", "yml"],
    "scopeName": "source.yaml",
    "patterns": [
        {
            "name": "comment.line.number-sign.yaml",
            "match": "#.*",
            "captures": {
                "0": {
                    "name": "punctuation.definition.comment.yaml"
                }
            }
        },
        {
            "name": "entity.name.tag.yaml",
            "match": "^\\s*\\w+",
            "captures": {
                "0": {
                    "name": "punctuation.definition.tag.yaml"
                }
            }
        },
        {
            "name": "punctuation.separator.key-value.yaml",
            "match": ":",
            "captures": {
                "0": {
                    "name": "punctuation.separator.key-value.yaml"
                }
            }
        },
        {
            "name": "string.quoted.double.yaml",
            "begin": "\"",
            "end": "\"",
            "patterns": [
                {
                    "name": "constant.character.escape.yaml",
                    "match": "\\\\(x[0-9A-Fa-f]{2}|u[0-9A-Fa-f]{4}|U[0-9A-Fa-f]{6}|.)"
                }
            ]
        },
        {
            "name": "string.quoted.single.yaml",
            "begin": "'",
            "end": "'",
            "patterns": [
                {
                    "name": "constant.character.escape.yaml",
                    "match": "''"
                }
            ]
        }
    ],
    "repository": {
        "scalar-plain": {
            "patterns": [
                {
                    "match": "\\b(\\w+)\\b",
                    "name": "scalar.plain.yaml"
                }
            ]
        }
    }
}
""";

final armasmGrammar = r'''
{
  "name": "Nasm",
  "version": "1.0.0",
  "fileTypes": ["asm", "asm"],
  "scopeName": "source.armasm",

  "patterns": [
    {
      "include": "#comments"
    },
    {
      "include": "#keywords"
    }
  ],

  "repository": {
    "comments": {
      "patterns": [
        {
          "name": "comment.line.double-semicolon.nasm",
          "match": ";;.*$"
        }
      ]
    },
    "keywords": {
      "patterns": [
        {
          "name": "keyword.control.nasm",
          "match": "^\\s*[\\w\\.]+\\b"
        },
        {
          "name": "keyword.control.nasm",
          "match": "\\b->[\\w\\.]+\\b"
        }

      ]
    },
    "strings": {
      "patterns": [
        {
          "name": "string.quoted.double.cpp",
          "begin": "\"",
          "end": "\""
        },
        {
          "name": "string.quoted.single.cpp",
          "begin": "'",
          "end": "'"
        }
      ]
    }
  }
}
''';
