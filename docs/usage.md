# Request and result guide

Every example below is an executable fixture. Assertions cover the listed result fields; additional output fields are documented by the API and other fixtures. Error cases intentionally reject the request.

## arithmetic precedence

```json
{
  "operation": "evaluate",
  "expression": "1 + 2 * 3 == 7 && true",
  "facts": {}
}
```

Expected result fields:

```json
{
  "value": true
}
```

## short circuit

```json
{
  "operation": "evaluate",
  "expression": "false && (1 / 0 > 1)",
  "facts": {}
}
```

Expected result fields:

```json
{
  "value": false
}
```

## missing exists

```json
{
  "operation": "evaluate",
  "expression": "exists(user.age)",
  "facts": {}
}
```

Expected result fields:

```json
{
  "value": false
}
```

## priority first

```json
{
  "rules": [
    {
      "id": "adult",
      "priority": 2,
      "when": "age >= 18",
      "output": "adult"
    },
    {
      "id": "fallback",
      "when": "true",
      "output": "other"
    }
  ],
  "facts": {
    "age": 20
  }
}
```

Expected result fields:

```json
{
  "results/0/result/decision": "adult"
}
```

## unique conflict

```json
{
  "rules": [
    {
      "id": "adult",
      "priority": 2,
      "when": "age >= 18",
      "output": "adult"
    },
    {
      "id": "fallback",
      "when": "true",
      "output": "other"
    }
  ],
  "facts": {
    "age": 20
  },
  "mode": "unique"
}
```

Expected result fields:

```json
{
  "results/0/result/conflict": true,
  "results/0/result/decision": null
}
```

## all matches

```json
{
  "rules": [
    {
      "id": "adult",
      "priority": 2,
      "when": "age >= 18",
      "output": "adult"
    },
    {
      "id": "fallback",
      "when": "true",
      "output": "other"
    }
  ],
  "facts": {
    "age": 20
  },
  "mode": "all"
}
```

Expected result fields:

```json
{
  "results/0/result/decision": [
    "adult",
    "other"
  ]
}
```

## division zero

```json
{
  "operation": "evaluate",
  "expression": "1 / 0",
  "facts": {}
}
```

Expected: nonzero exit with an input error.

## strict boolean

```json
{
  "operation": "evaluate",
  "expression": "1 && true",
  "facts": {}
}
```

Expected: nonzero exit with an input error.

## duplicate rules

```json
{
  "rules": [
    {
      "id": "adult",
      "priority": 2,
      "when": "age >= 18",
      "output": "adult"
    },
    {
      "id": "adult",
      "priority": 2,
      "when": "age >= 18",
      "output": "adult"
    }
  ],
  "facts": {}
}
```

Expected: nonzero exit with an input error.
