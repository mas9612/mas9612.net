---
title: "C++のstd::vectorについて"
date: 2016-07-24T00:00:00+09:00
draft: false
---

std::vectorについて勉強しなおした．

STLコンテナの一種．実行時に動的にサイズを変更できる．vectorを使用するためには， `#include <vector>` を記述する必要がある．

## vectorの生成
vectorには複数のコンストラクタが存在する．

```cpp
const int data[] = {1, 2, 3, 4, 5};

std::vector<int> empty_vector;                  // 空のvector
std::vector<int> int_vector(10);                // 要素数10のvector
std::vector<double> double_vector(10, 3.2);     // 要素数10，各要素は3.2で初期化されたvector
std::vector<double> copy_vector(double_vector); // double_vectorのコピー
std::vector<int> iter_vector(data, data + 5);   // dataからdata+5の要素をもつvector
```

## vectorのサイズ・容量
vectorでは，実際に確保されている動的配列の要素数と，実際に使用されている動的配列の要素数は異なる．これらの値を調べたい時には，それぞれ `capacity()` 関数， `size()` 関数を使用する．これらの関数の戻り値は， `std::vector::size_type` 型である．

vectorで使用できるサイズの最大値は `max_size()` 関数で得ることができる．

```cpp
std::vector<int> v;

std::cout << v.capacity()   // 確保されている要素数
    << v.size()       // 使用されている要素数
    << v.max_size()   // std::vector<int>で使用できる最大要素数
    << std::endl;
```
vectorの容量を拡張したい時には， `reserve()` 関数を使用する．

```cpp
std::vector<int> v;

v.reserve(100);
```

## vectorの操作

### 要素の追加・代入
vectorの末尾に値を追加するには， `push_back()` 関数を使用する．要素追加時には，容量の拡張は自動的に行われる．
また，任意の位置に値を挿入するには， `insert()` 関数を使用する．

```cpp
std::vector<int> v(5, 1);

v.push_back(3);     // vの末尾に3を追加
v.(v.begin(), 10);  // vの先頭に10を挿入
```

vectorへの値の代入には， `=` 演算子が使用できる．さらに， `assign()` 関数を使用することもできる．

```cpp
std::vector<int> v(10);

v.assign(10, 1);    // 10個の1を代入
v[5] = 0;           // v[5]に0を代入

const int a[] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
v.assign(a, a + 10);    // aからa+10の要素を代入
```

### 要素の取得
要素にアクセスするには，通常の配列のように `[]` を使用することができる．添字アクセスの際には容量の拡張は行われないため，サイズ以上の値を指定した場合は範囲外アクセスになる．

範囲外アクセスに対応したい場合には， `at()` 関数を使用する．この関数を使用している際に範囲外アクセスが起こると， `std::out_of_range` 例外が送出される．

```cpp
std::vector<int> v(10, 3);
try {
cout << v[3] << '\n';   // 3が表示される
v.at(15) = 13;          // std::out_of_range例外の送出
} catch (const std::out_of_range& e) {
std::cerr << e.what() << std::endl;
}
```

また，先頭の要素は `front()` 関数，末尾の要素は `back()` 関数で取得できる．

```cpp
std::vector<int> v(10);
std::cout << v.front() << '\n';
std::cout << v.back()  << '\n';
```

### 要素の削除
要素の削除には， `pop_back()` 関数，もしくは `erase()` 関数を使用する．なお，要素を削除しても，その領域は残ったままになる．そのため， `new` で確保した領域を削除した場合でも，自動的に `delete` されない．

```cpp
std::vector<int> v(10, 1);

v.pop_back();                       // 末尾の要素を削除
v.erase(v.begin());                 // 先頭要素を削除
v.erase(v.begin() + 2, v.end());    // 3番めの要素から最後まで削除
```

要素をすべて削除したい場合は， `clear()` 関数を使用する．

```cpp
std::vector<int> v(5, 5);

v.clear();
```
