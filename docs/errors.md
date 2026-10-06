# Error code taxonomy

Every input error carries a stable E-code prefix followed by its message: `E2001 missing fact: user.age`. Hosts branch on the code instead of parsing prose.

| Code | Class | Meaning |
| --- | --- | --- |
| E1001 | parser | expression exceeds 65,536 characters |
| E1002 | parser | unterminated string literal |
| E1003 | parser | character outside the token grammar |
| E1004 | parser | expression ends where a value was required |
| E1005 | parser | missing closing parenthesis |
| E1006 | parser | operator where a value was expected |
| E1007 | parser | nesting deeper than 128 levels |
| E1008 | parser | function not in the allow-list |
| E1009 | parser | tokens after a complete expression |
| E2001 | evaluation | fact path absent at evaluation time |
| E2002 | evaluation | logical operand is not boolean |
| E2003 | evaluation | comparison across incompatible types |
| E2004 | evaluation | unary operator not in the allow-list |
| E2005 | evaluation | operator not in the grammar |
| E2006 | evaluation | function argument types invalid |
| E2007 | evaluation | non-finite arithmetic result |
| E2008 | evaluation | division by zero or substring out of bounds |
| E2009 | evaluation | evaluation budget exhausted |
| E3001 | request | string value required |
| E3002 | request | array value required |
| E3003 | request | object value required |
| E3004 | request | finite number required |
| E3005 | request | unknown operation |
| E3006 | request | decision mode not in first/all/unique |
| E3007 | request | budget outside 1..1,000,000 |
| E3008 | request | schema type name not recognized |
| E3009 | request | schema is not an object |
| E3010 | request | explain given a record count other than one |
| E4001 | rules | duplicate rule ID |
| E4002 | rules | duplicate metric name in aggregate |
| E4003 | rules | metric op requires an expression |
| E4004 | rules | count metric takes no expression |
| E4005 | rules | unknown metric op |
| E4006 | rules | rule without an ID in analyze |
| E4007 | rules | compute is not a string |

Run `python3 -B scripts/error_codes.py` to assert every listed code against the real CLI.
