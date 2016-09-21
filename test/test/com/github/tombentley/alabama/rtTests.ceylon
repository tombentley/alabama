import ceylon.collection {
    ArrayList,
    LinkedList,
    HashMap
}
import ceylon.language.meta {
    type,
    typeLiteral
}
import ceylon.test {
    assertEquals,
    test,
    assertTrue
}

import com.github.tombentley.alabama {
    deserialize,
    serialize,
    StringSerializer
}

import ceylon.time{
    DateTime,
    dateTime,
    Date,
    date
}
import ceylon.language.serialization {
    SerializationException
}
import ceylon.time.iso8601 {
    parseDate
}

test
shared void rtEmptyArray() {
    variable Array<Integer> a = Array<Integer>{};
    
    // with static type info
    variable value json = serialize(a, false);
    assertEquals {
        actual = json;
        expected = """[]""";
    };
    variable value a2 = deserialize<Array<Anything>>(json);
    assertEquals {
        actual = a2.size;
        expected = 0;
    };
    assert(! a2[0] exists);
    
    // without static type info
    a = Array<Integer>{};
    json = serialize<Object>(a, false);
    assertEquals {
        actual = json;
        expected = """{"class":"ceylon.language::Array<ceylon.language::Integer>","value":[]}""";
    };
    value a3 = deserialize<Object>(json);
    assert(is Array<Integer> a3);
    assertEquals {
        actual = a3.size;
        expected = 0;
    };
    assert(! a3[0] exists);
}

test
shared void rtArray() {
    variable Array<Integer> a = Array<Integer>{1,2,3};
    
    // with static type info
    variable value json = serialize(a, false);
    assertEquals {
        actual = json;
        expected = """[1,2,3]""";
    };
    value a2 = deserialize<Array<Anything>>(json);
    assertEquals {
        actual = a2.size;
        expected = 3;
    };
    assert(exists a20=a2[0], a20 == 1);
    assert(exists a21=a2[1], a21 == 2);
    assert(exists a22=a2[2], a22 == 3);
    
    // without static type info
    json = serialize<Object>(a, false);
    assertEquals {
        actual = json;
        expected = """{"class":"ceylon.language::Array<ceylon.language::Integer>","value":[1,2,3]}""";
    };
    value a3 = deserialize<Object>(json);
    assert(is Array<Integer> a3);
    assertEquals {
        actual = a3.size;
        expected = 3;
    };
    assert(exists a30=a2[0], a30 == 1);
    assert(exists a31=a2[1], a31 == 2);
    assert(exists a32=a2[2], a32 == 3);
}

test
shared void rtCyclicArray() {
    Array<Anything> l = Array<Anything>.ofSize(1, null);
    l.set(0, l);
    
    // with static type info
    variable value json = serialize(l, false);
    assertEquals {
        actual = json;
        expected = """{"#":1,"value":[{"@":1}]}""";
    };
    variable value y = deserialize<Array<Anything>>(json);
    assert(is Identifiable x=y[0], x === y); 
    
    // without static type info
    json = serialize(l of Object, false);
    assertEquals {
        actual = json;
        expected = """{"class":"ceylon.language::Array<ceylon.language::Anything>","#":1,"value":[{"@":1}]}""";
    };
    value y2 = deserialize<Object>(json);
    assert(is Array<Anything> y2);
    assert(is Identifiable x2=y2[0], x2 === y2);
}

serializable class Foo() {}

test
shared void testIdentifiableAndArray() {
    value foo = Foo();
    value s = foo->Array{foo};
    
    // with static type info
    variable value json = serialize(s, false);
    assertEquals {
        actual = json;
        expected = """{"key":{"#":1},"item":[{"@":1}]}""";
    };
    variable value y = deserialize<Foo->Array<Foo>>(json);
    assert(exists a= y.item[0], 
        y.key === a);
    
    // without static type info
    json = serialize<Object>(s, false);
    assertEquals {
        actual = json;
        expected = """{"class":"ceylon.language::Entry<test.com.github.tombentley.alabama::Foo,ceylon.language::Array<test.com.github.tombentley.alabama::Foo>>","key":{"#":1},"item":[{"@":1}]}""";
    };
    assert(is Foo->Array<Foo> z = deserialize<Object>(json));
    assert(exists b= z.item[0], 
        z.key === b);
}


test
shared void rtTuple() {
    value tuple1 = [1, "2", true];
    
    // with static type info
    variable value json = serialize(tuple1, false);
    assertEquals {
        actual = json;
        expected = """[1,"2",true]""";
    };
    assertEquals {
        actual = deserialize<[Integer, String, Boolean]>(json);  
        expected = tuple1; 
    };
    
    json = serialize([Generic("S")], false);
    assertEquals {
        actual = json;
        expected = """[{"element":"S"}]""";
    };
    assertEquals { 
        actual = deserialize<[Generic<String>]>(json)[0].element; 
        expected = "S"; 
    };
    
    json = serialize(Generic(tuple1), false);
    assertEquals {
        actual = json;
        expected = """{"element":[1,"2",true]}""";
    };
    assertEquals { 
        actual = deserialize<Generic<[Integer, String, Boolean]>>(json).element; 
        expected = tuple1;
    };
    
    // TODO support tuple type abbrevs
    // without static type info
    json = serialize<Object>(tuple1, false);
    assertEquals {
        actual = json;
        expected = """{"class":"ceylon.language::Tuple<ceylon.language::true|ceylon.language::String|ceylon.language::Integer,ceylon.language::Integer,ceylon.language::Tuple<ceylon.language::true|ceylon.language::String,ceylon.language::String,ceylon.language::Tuple<ceylon.language::true,ceylon.language::true,ceylon.language::empty>>>","value":[1,"2",true]}""";
    };
    assertEquals { 
        actual = deserialize<Object>(json); 
        expected = tuple1; 
    };
    
    json = serialize<Object>([Generic("S")], false);
    assertEquals(json, """{"class":"ceylon.language::Tuple<test.com.github.tombentley.alabama::Generic<ceylon.language::String>,test.com.github.tombentley.alabama::Generic<ceylon.language::String>,ceylon.language::empty>","value":[{"class":"test.com.github.tombentley.alabama::Generic<ceylon.language::String>","element":"S"}]}""");
    assert(is [Generic<String>] got = deserialize<Object>(json));
    assertEquals { 
        actual = got[0].element; 
        expected = "S"; 
    };
    
    json = serialize<Object>(Generic(tuple1), false);
    assertEquals {
        actual = json;
        expected = """{"class":"test.com.github.tombentley.alabama::Generic<ceylon.language::Tuple<ceylon.language::Integer|ceylon.language::String|ceylon.language::Boolean,ceylon.language::Integer,ceylon.language::Tuple<ceylon.language::String|ceylon.language::Boolean,ceylon.language::String,ceylon.language::Tuple<ceylon.language::Boolean,ceylon.language::Boolean,ceylon.language::Empty>>>>","element":[1,"2",true]}""";
    };
    assert(is Generic<[Integer, String, Boolean]> got2 = deserialize<Object>(json));
    assertEquals { 
        actual = got2.element; 
        expected = tuple1; 
    };
}
test
shared void rtTupleWithRest() {
    value tuple = [1, "2", true, *(4..6)];
    
    // with static type info
    variable value json = serialize(tuple, true);
    assertEquals{
        expected = """[
                       1,
                       "2",
                       true,
                       4,
                       5,
                       6
                      ]""";
        actual = json;
    };
    value got1 = deserialize<[Integer|String|Boolean*]>(json);
    assertEquals{
        expected = tuple;
        actual = got1;
    };
    
    // without static type info
    
    // TODO In this case all I actually need to know from the wrapper class
    // is that the JSON array is a Tuple (I don't need the tuple instantiation)
    // because the reification of tuple uses the runtime types
    json = serialize(tuple of Object, true);
    assertEquals{
        expected = """{
                       "class": "ceylon.language::Tuple<ceylon.language::true|ceylon.language::String|ceylon.language::Integer,ceylon.language::Integer,ceylon.language::Tuple<ceylon.language::true|ceylon.language::String|ceylon.language::Integer,ceylon.language::String,ceylon.language::Tuple<ceylon.language::Integer|ceylon.language::true,ceylon.language::true,ceylon.language::Span<ceylon.language::Integer>>>>",
                       "value": [
                        1,
                        "2",
                        true,
                        4,
                        5,
                        6
                       ]
                      }""";
        actual = json;
    };
    value got2 = deserialize<Object>(json);
    assertEquals{
        expected = tuple;
        actual = got2;
    };
    
}

test
shared void rtArraySequence() {
    assert(is ArraySequence<Integer|String|Boolean> as = Array{1, "2", true}.sequence());
    
    // with static type info
    variable value json = serialize(as);
    assertEquals {
        actual = json;
        expected = """[1,"2",true]""";
    };
    value as2 = deserialize<ArraySequence<Integer|String|Boolean>>(json);
    assert(as2 == as);
    
    // without static type info
    json = serialize<Object>(as);
    assertEquals {
        actual = json;
        expected = """{"class":"ceylon.language::ArraySequence<ceylon.language::Integer|ceylon.language::String|ceylon.language::Boolean>","value":[1,"2",true]}""";
    };
    assert(is ArraySequence<Integer|String|Boolean> as3 = deserialize<Object>(json));
    assert(as3 == as);
}

test
shared void rtArraySequenceInGeneric() {
    assert(is ArraySequence<Integer|String|Boolean> as = Array{1, "2", true}.sequence());
    value g = Generic(as);
    
    // with static type info
    variable value json = serialize(g);
    assertEquals {
        actual = json;
        expected = """{"element":[1,"2",true]}""";
    };
    value as3 = deserialize<Generic<ArraySequence<Integer|String|Boolean>>>(json);
    assert(as3.element == as);
    
    // without static type info
    json = serialize<Object>(g);
    assertEquals {
        actual = json;
        expected = """{"class":"test.com.github.tombentley.alabama::Generic<ceylon.language::ArraySequence<ceylon.language::Integer|ceylon.language::String|ceylon.language::Boolean>>","element":[1,"2",true]}""";
    };
    assert(is Generic<ArraySequence<Integer|String|Boolean>> as4 = deserialize<Object>(json));
    assert(as4.element == as);
    
    // TODO without static type info
}


// TODO a non-serializable class
// TODO getting the right type info for attributes, and elements

test
shared void rtString() {
    // with static type info
    variable String json = serialize("hello, world");
    assertEquals {
        actual = json;
        expected = """"hello, world"""";
    };
    assertEquals {
        actual = deserialize<String>(json);
        expected = "hello, world";
    };
    
    // without static type info
    json = serialize("hello, world" of Object);
    assertEquals {
        actual = json;
        expected = """"hello, world"""";
    };
    assertEquals {
        actual = deserialize<Object>(json);
        expected = "hello, world";
    };
    
    json = serialize("hello, world" of String?);
    assertEquals {
        actual = json;
        expected = """"hello, world"""";
    };
    assertEquals {
        actual = deserialize<String?>(json);
        expected = "hello, world";
    };
}

test
shared void rtInteger() {
    // with static type info
    variable String json = serialize(42);
    assertEquals {
        actual = json;
        expected = """42""";
    };
    assertEquals {
        actual = deserialize<Integer>(json);
        expected = 42;
    };
    
    // without static type info
    json = serialize(42 of Object);
    assertEquals {
        actual = json;
        expected = """42""";
    };
    assertEquals {
        actual = deserialize<Object>(json);
        expected = 42;
    };
}

test
shared void rtFloat() {
    // with static type info
    variable String json = serialize(42.5);
    assertEquals {
        actual = json;
        expected = """42.5""";
    };
    assertEquals {
        actual = deserialize<Float>(json);
        expected = 42.5;
    };
    
    // without static type info
    json = serialize(42.5 of Object);
    assertEquals {
        actual = json;
        expected = """42.5""";
    };
    assertEquals {
        actual = deserialize<Object>(json);
        expected = 42.5;
    };
}

test
shared void rtMinusZero() {
    // with static type info
    variable String json = serialize(-0.0);
    assertEquals {
        actual = json;
        expected = """-0.0""";
    };
    value got = deserialize<Float>(json);
    assertEquals {
        actual = got;
        expected = -0.0;
    };
    assertTrue {
        condition = got.strictlyNegative;
    };
    
    // TODO without static type info
}

test
shared void rtNaN() {
    // with static type info
    variable String json = serialize(0.0/0.0);
    assertEquals {
        actual = json;
        expected = """"NaN"""";
    };
    assertTrue(deserialize<Float>(json).undefined);
    
    // without static type info
    json = serialize<Object>(0.0/0.0);
    assertEquals {
        actual = json;
        expected = """{"class":"ceylon.language::Float","value":"NaN"}""";
    };
    assertTrue(deserialize<Float>(json).undefined);
}

test
shared void rtInfinity() {
    // with static type info
    variable String json = serialize(infinity);
    assertEquals {
        actual = json;
        expected = """"∞"""";
    };
    assertEquals {
        actual = deserialize<Float>(json);
        expected = infinity;
    };
    
    // without static type info
    json = serialize<Object>(infinity);
    assertEquals {
        actual = json;
        expected = """{"class":"ceylon.language::Float","value":"∞"}""";
    };
    assertEquals {
        actual = deserialize<Float>(json);
        expected = infinity;
    };
}
test
shared void rtNegativeInfinity() {
    // with static type info
    variable String json = serialize(-infinity);
    assertEquals {
        actual = json;
        expected = """"-∞"""";
    };
    assertEquals {
        actual = deserialize<Float>(json);
        expected = -infinity;
    };
    
    // without static type info
    json = serialize<Object>(-infinity);
    assertEquals {
        actual = json;
        expected = """{"class":"ceylon.language::Float","value":"-∞"}""";
    };
    assertEquals {
        actual = deserialize<Float>(json);
        expected = -infinity;
    };
}

test
shared void rtInfinityInTuple() {
    // with static type info
    variable String json = serialize([infinity]);
    assertEquals {
        actual = json;
        expected = """["∞"]""";
    };
    assertEquals {
        actual = deserialize<[Float]>(json);
        expected = [infinity];
    };
    
    // without static type info
    json = serialize<Object>([infinity]);
    assertEquals {
        actual = json;
        expected = """{"class":"ceylon.language::Tuple<ceylon.language::Float,ceylon.language::Float,ceylon.language::empty>","value":[{"class":"ceylon.language::Float","value":"∞"}]}""";
    };
    assertEquals {
        actual = deserialize<Object>(json);
        expected = [infinity];
    };
    
}

test
shared void rtBoolean() {
    // with static type info
    variable String json = serialize(true);
    assertEquals {
        actual = json;
        expected = """true""";
    };
    assertEquals {
        actual = deserialize<Boolean>(json);
        expected = true;
    };
    
    // without static type info
    json = serialize(true of Object);
    assertEquals {
        actual = json;
        expected = """true""";
    };
    assertEquals {
        actual = deserialize<Object>(json);
        expected = true;
    };
}

test
shared void rtNull() {
    // without static type info
    variable String json = serialize(null);
    assertEquals {
        actual = json;
        expected = """null""";
    };
    assertEquals {
        actual = deserialize<Anything>(json);
        expected = null;
    };
    
    // with static type info (as much as possible, anyway)
    json = serialize(null of String?);
    assertEquals {
        actual = json;
        expected = """null""";
    };
    assertEquals {
        actual = deserialize<String?>(json);
        expected = null;
    };
}

test
shared void rtCharacter() {
    // with static type info
    variable String json = serialize('x');
    assertEquals {
        actual = json;
        expected = """"x"""";
    };
    assertEquals {
        actual = deserialize<Character>(json);
        expected = 'x';
    };
    
    // without static type info
    json = serialize<Object>('x' of Object);
    assertEquals {
        actual = json;
        expected = """{"class":"ceylon.language::Character","value":"x"}""";
    };
    assertEquals {
        actual = deserialize<Object>(json);
        expected = 'x';
    };
}


test
shared void rtEmpty() {
    // with static type info
    variable String json = serialize([]);
    assertEquals {
        actual = json;
        expected = """{"class":"ceylon.language::empty"}""";
    };
    assertEquals {
        actual = deserialize<[]>(json);
        expected = [];
    };
    
    // without static type info
    json = serialize<Object>([]);
    assertEquals {
        actual = json;
        expected = """{"class":"ceylon.language::empty"}""";
    };
    assertEquals {
        actual = deserialize<Object>(json);
        expected = [];
    };
}

test
shared void rtLarger() {
    // there's nothing "special" about larger, it's just a good example
    // of a toplevel object where we have to resolve the value rather 
    // than instantiate the class
    
    // with static type info
    variable String json = serialize(larger);
    assertEquals {
        actual = json;
        expected = """{"class":"ceylon.language::larger"}""";
    };
    assertEquals {
        actual = deserialize<\Ilarger>(json);
        expected = larger;
    };
    assertEquals {
        actual = deserialize<Comparison>(json);
        expected = larger;
    };
    
    // without static type info
    json = serialize(larger of Object);
    assertEquals {
        actual = json;
        expected = """{"class":"ceylon.language::larger"}""";
    };
    assertEquals {
        actual = deserialize<Object>(json);
        expected = larger;
    };
}

serializable class StringContainer(string) {
    shared actual String string;
}

"Test with a simple class with a concrete class-typed attribute"
test
shared void rtStringContainer() {
    // with static type info
    variable String json = serialize(StringContainer("hello, world"));
    assertEquals {
        actual = json;
        expected = """{"string":"hello, world"}""";
    };
    assertEquals {
        actual = deserialize<StringContainer>(json).string;
        expected = "hello, world";
    };
    
    // with static type info
    json = serialize(StringContainer("hello, world") of Object);
    assertEquals {
        actual = json;
        expected = """{"class":"test.com.github.tombentley.alabama::StringContainer","string":"hello, world"}""";
    };
    assertEquals {
        actual = deserialize<Object>(json).string;
        expected = "hello, world";
    };
}


serializable class Generic<Element>(element) {
    shared Element element;
    shared actual String string => "Generic<``typeLiteral<Element>()``>(``element else "null"``)";
}

test
shared void rtGenericString() {
    value generic = Generic("hello, world");
    
    // with static type info
    variable String json = serialize(generic);
    assertEquals {
        actual = json;
        expected = """{"element":"hello, world"}""";
    };
    assertEquals {
        actual = deserialize<Generic<String>>(json).element;
        expected = "hello, world";
    };
    
    // without static type info
    json = serialize(generic of Object);
    assertEquals {
        actual = json;
        expected = """{"class":"test.com.github.tombentley.alabama::Generic<ceylon.language::String>","element":"hello, world"}""";
    };
    assert(is Generic<String> o = deserialize<Object>(json));
    assertEquals {
        actual = o.element;
        expected = "hello, world";
    };
}

test
shared void rtGenericOptionalString() {
    value hello = Generic<String?>("hello, world");
    
    // with static type info
    variable String json = serialize(hello);
    assertEquals {
        actual = json;
        expected = """{"element":"hello, world"}""";
    };
    assertEquals {
        actual = deserialize<Generic<String?>>(json).element;
        expected = "hello, world";
    };
    
    // without static type info
    json = serialize(hello of Object);
    assertEquals {
        actual = json;
        expected = """{"class":"test.com.github.tombentley.alabama::Generic<ceylon.language::Null|ceylon.language::String>","element":"hello, world"}""";
    };
    assert(is Generic<String?> o = deserialize<Object>(json));
    assertEquals {
        actual = o.element;
        expected = "hello, world";
    };
}
test
shared void rtGenericOptionalStringNull() {
    value nul = Generic<String?>(null);
    
    // with static type info
    variable value json = serialize(nul);
    assertEquals {
        actual = json;
        expected = """{"element":null}""";
    };
    assertEquals {
        actual = deserialize<Generic<String?>>(json).element;
        expected = null;
    };
    
    // without static type info
    json = serialize(nul of Object);
    assertEquals {
        actual = json;
        expected = """{"class":"test.com.github.tombentley.alabama::Generic<ceylon.language::Null|ceylon.language::String>","element":null}""";
    };
    assert(is Generic<String?> o2 = deserialize<Object>(json));
    assertEquals {
        actual = o2.element;
        expected = null;
    };
}

test
shared void rtGenericCharacter() {
    value x = Generic('x');
    
    // with static type info
    variable String json = serialize(x);
    assertEquals {
        actual = json;
        expected = """{"element":"x"}""";
    };
    assertEquals {
        actual = deserialize<Generic<Character>>(json).element;
        expected = 'x';
    };
    
    // with static type info
    json = serialize(x of Object);
    assertEquals {
        actual = json;
        expected = """{"class":"test.com.github.tombentley.alabama::Generic<ceylon.language::Character>","element":"x"}""";
    };
    assert(is Generic<Character> o = deserialize<Object>(json));
    assertEquals {
        actual = o.element;
        expected = 'x';
    };
}

test
shared void rtGenericEmpty() {
    value a = Generic([] of String[]);
    
    // with static type info
    variable String json = serialize(a);
    assertEquals {
        actual = json;
        expected = """{"element":{"class":"ceylon.language::empty"}}""";
    };
    assertEquals {
        actual = deserialize<Generic<String[]>>(json).element;
        expected = [];
    };
    
    // without static type info
    json = serialize(a of Object);
    assertEquals {
        actual = json;
        expected = """{"class":"test.com.github.tombentley.alabama::Generic<ceylon.language::Sequential<ceylon.language::String>>","element":{"class":"ceylon.language::empty"}}""";
    };
    assert(is Generic<String[]> o = deserialize<Object>(json));
    assertEquals {
        actual = o.element;
        expected = [];
    };
}

test
shared void rtGenericLarger() {
    value generic = Generic(larger);
    
    // with static type info
    variable String json = serialize(generic);
    assertEquals {
        actual = json;
        expected = """{"element":{"class":"ceylon.language::larger"}}""";
    };
    assertEquals {
        actual = deserialize<Generic<Comparison>>(json).element;
        expected = larger;
    };
    
    // without static type info
    json = serialize(generic of Object);
    assertEquals {
        actual = json;
        expected = """{"class":"test.com.github.tombentley.alabama::Generic<ceylon.language::Comparison>","element":{"class":"ceylon.language::larger"}}""";
    };
    assert(is Generic<Comparison> o = deserialize<Object>(json));
    assertEquals {
        actual = o.element;
        expected = larger;
    };
}

serializable class Late() {
    shared late String required;
    shared late String? nullable;
}

"tests we can serialize and deserialize objects with uninitialized late attributes"
test
shared void rtLate() {
    variable String json = serialize(Late() of Object);
    assertEquals(json, """{"class":"test.com.github.tombentley.alabama::Late"}""");
    variable Late r = deserialize<Late>(json);
    r.required = "";
    r.nullable = null;
    
    Late l = Late();
    l.required = "req";
    l.nullable = "nul";
    json = serialize(l, true);
    assertEquals(json,
        """{
            "required": "req",
            "nullable": "nul"
           }""");
    r = deserialize<Late>(json);
    assertEquals(r.required, "req");
    assertEquals(r.nullable, "nul");
}

serializable class LateVariable() {
    shared variable late String required;
    shared variable late String? nullable;
}
"tests we can serialize and deserialize objects with uninitialized late variableattributes"
test
shared void rtLateVariable() {
    variable String json = serialize(LateVariable() of Object);
    assertEquals(json, """{"class":"test.com.github.tombentley.alabama::LateVariable"}""");
    variable LateVariable r = deserialize<LateVariable>(json);
    r.required = "";
    r.nullable = null;
    
    LateVariable l = LateVariable();
    l.required = "req";
    l.nullable = "nul";
    json = serialize(l, true);
    assertEquals(json,
        """{
            "required": "req",
            "nullable": "nul"
           }""");
    r = deserialize<LateVariable>(json);
    assertEquals(r.required, "req");
    assertEquals(r.nullable, "nul");
}

test
shared void rtSingleton() {
    variable value json = serialize(Singleton('x'));
    assertEquals(json, """["x"]""");
    assertEquals(deserialize<Singleton<Character>>(json), Singleton('x'));
    
    json = serialize(Singleton('x' of Object));
    assertEquals(json, """[{"class":"ceylon.language::Character","value":"x"}]""");
    // Need to know it's supposed to be a singleton, otherwise we just get ArraySequence
    assertEquals(deserialize<Singleton<Anything>>(json), Singleton('x'));
    assertEquals(deserialize<Object>(json), Singleton('x'));
    
    json = serialize(Generic<Object>(Singleton('x')));
    print(json);
    //assertEquals(json, """{"element":[{"class":"ceylon.language::Character","character":"x"}]}""");
    
    json = serialize<Object>(Generic(Singleton('x')));
    print(json);
    //assertEquals(json, """{"element":[{"class":"ceylon.language::Character","character":"x"}]}""");
}

serializable class Zero() {
    shared actual Boolean equals(Object other) {
        return other is Zero;
    }
}
serializable class One(first) {
    Anything first;
    shared actual Boolean equals(Object other) {
        if (is One other) {
            if (is Object first, is Object f=other.first) {
                return first == f;
            } else if (!first is Object ) {
                return !other.first is Object; 
            } else {
                return false; 
            }
        } else {
            return false;
        }
    }
    shared Anything f => first;
}
serializable class Two(left, right) {
    Anything left;
    Anything right;
    shared actual Boolean equals(Object other) {
        if (is Two other) {
            variable Boolean same;
            if (exists left) {
                same = other.left is Object;
            } else {
                same = !other.left is Object;
            }
            if (same) {
                if (exists right) {
                    same = other.right is Object;
                } else {
                    same = !other.right is Object;
                }
            }
            return same;
        } else {
            return false;
        }
    }
    shared Anything l => left;
    shared Anything r => right;
}
test
shared void rtDiamond() {
    Zero zero = Zero();
    One left = One(zero);
    One right = One(zero);
    Two top = Two(left, right);
    
    // with static type info
    variable value json = serialize(top, true);
    assertEquals(json, """{
                           "left": {
                            "class": "test.com.github.tombentley.alabama::One",
                            "first": {
                             "class": "test.com.github.tombentley.alabama::Zero",
                             "#": 1
                            }
                           },
                           "right": {
                            "class": "test.com.github.tombentley.alabama::One",
                            "@first": 1
                           }
                          }""");
    Two t = deserialize<Two>(json);
    assert(is One l = t.l);
    assert(is One r = t.r);
    assert(is Zero z1 = l.f);
    assert(is Zero z2 = r.f);
    assert(z1 === z2);
    
    // without static type info
    json = serialize<Object>(top, true);
    assertEquals(json, """{
                           "class": "test.com.github.tombentley.alabama::Two",
                           "left": {
                            "class": "test.com.github.tombentley.alabama::One",
                            "first": {
                             "class": "test.com.github.tombentley.alabama::Zero",
                             "#": 1
                            }
                           },
                           "right": {
                            "class": "test.com.github.tombentley.alabama::One",
                            "@first": 1
                           }
                          }""");
    assert(is Two t2 = deserialize<Object>(json));
    assert(is One l2 = t2.l);
    assert(is One r2 = t2.r);
    assert(is Zero z12 = l2.f);
    assert(is Zero z22 = r2.f);
    assert(z12 === z22);
}

test
shared void rtMeasure() {
    value m = measure(1, 3);
    // note that a "class" is always included, because the static type is Range
    // which is not good enough
    variable value json = serialize(m, true);
    assertEquals(json, """{
                           "class": "ceylon.language::Measure<ceylon.language::Integer>",
                           "first": 1,
                           "size": 3
                          }""");
    assert(is Range<Integer> r = deserialize<Object>(json));
    assertEquals(r, m);
    // check we got the right type
    assertEquals(type(r).string, "ceylon.language::Measure<ceylon.language::Integer>");
}

test
shared void rtSpan() {
    value m = span(1, 3);
    // note that a "class" is always included, because the static type is Range
    // which is not good enough
    variable value json = serialize(m, true);
    assertEquals(json, """{
                           "class": "ceylon.language::Span<ceylon.language::Integer>",
                           "first": 1,
                           "last": 3,
                           "recursive": false,
                           "increasing": true
                          }""");
    // TODO it's a shame we need those extra attributes
    assert(is Range<Integer> r = deserialize<Object>(json));
    assertEquals(r, m);
    // check we got the right type
    assertEquals(type(r).string, "ceylon.language::Span<ceylon.language::Integer>");
}

test
shared void rtArrayList() {
    value a = ArrayList{1, "foo", true};
    
    // with static type info
    variable value json = serialize(a, true);
    assertEquals(json, """{
                           "initialCapacity": 0,
                           "growthFactor": 1.5,
                           "array": [
                            1,
                            "foo",
                            true
                           ],
                           "length": 3
                          }""");
    value r = deserialize<ArrayList<Integer|String|Boolean>>(json);
    assertEquals(r, a);
    
    // without static type info
    json = serialize<Object>(a, true);
    assertEquals(json, """{
                           "class": "ceylon.collection::ArrayList<ceylon.language::Integer|ceylon.language::String|ceylon.language::Boolean>",
                           "initialCapacity": 0,
                           "growthFactor": 1.5,
                           "array": [
                            1,
                            "foo",
                            true
                           ],
                           "length": 3
                          }""");
    assert(is ArrayList<Integer|String|Boolean> r2 = deserialize<Object>(json));
    assertEquals(r2, a);
}

test
shared void rtLinkedList() {
    value a = LinkedList{1, "foo", true};
    
    // with static type info
    variable value json = serialize(a, true);
    assertEquals(json, """{
                           "head": {
                            "class": "ceylon.collection::Cell<ceylon.language::Integer|ceylon.language::String|ceylon.language::Boolean>",
                            "element": 1,
                            "rest": {
                             "class": "ceylon.collection::Cell<ceylon.language::Integer|ceylon.language::String|ceylon.language::Boolean>",
                             "element": "foo",
                             "rest": {
                              "class": "ceylon.collection::Cell<ceylon.language::Integer|ceylon.language::String|ceylon.language::Boolean>",
                              "#": 1,
                              "element": true,
                              "rest": null
                             }
                            }
                           },
                           "@tail": 1,
                           "length": 3
                          }""");
    value r = deserialize<LinkedList<Integer|String|Boolean>>(json);
    assertEquals(r, a);
    
    // without static type info
    json = serialize<Object>(a, true);
    assertEquals(json, """{
                           "class": "ceylon.collection::LinkedList<ceylon.language::Integer|ceylon.language::String|ceylon.language::Boolean>",
                           "head": {
                            "class": "ceylon.collection::Cell<ceylon.language::Integer|ceylon.language::String|ceylon.language::Boolean>",
                            "element": 1,
                            "rest": {
                             "class": "ceylon.collection::Cell<ceylon.language::Integer|ceylon.language::String|ceylon.language::Boolean>",
                             "element": "foo",
                             "rest": {
                              "class": "ceylon.collection::Cell<ceylon.language::Integer|ceylon.language::String|ceylon.language::Boolean>",
                              "#": 1,
                              "element": true,
                              "rest": null
                             }
                            }
                           },
                           "@tail": 1,
                           "length": 3
                          }""");
    value r2 = deserialize<Object>(json);
    assertEquals(r2, a);
}

test
shared void rtCyclicLinkedList() {
    value a = LinkedList<Object>{1};
    a.add(a);
    
    // with static type info
    variable value json = serialize(a, true);
    assertEquals(json, """{
                           "#": 1,
                           "head": {
                            "class": "ceylon.collection::Cell<ceylon.language::Object>",
                            "element": 1,
                            "rest": {
                             "class": "ceylon.collection::Cell<ceylon.language::Object>",
                             "#": 2,
                             "@element": 1,
                             "rest": null
                            }
                           },
                           "@tail": 2,
                           "length": 2
                          }""");
    value r = deserialize<LinkedList<Object>>(json);
    assert(exists r0=r[0],
        r0==1);
    assert(is Identifiable r1=r[1],
        r1===r);
    
    // without static type info
    json = serialize<Object>(a, true);
    assertEquals(json, """{
                           "class": "ceylon.collection::LinkedList<ceylon.language::Object>",
                           "#": 1,
                           "head": {
                            "class": "ceylon.collection::Cell<ceylon.language::Object>",
                            "element": 1,
                            "rest": {
                             "class": "ceylon.collection::Cell<ceylon.language::Object>",
                             "#": 2,
                             "@element": 1,
                             "rest": null
                            }
                           },
                           "@tail": 2,
                           "length": 2
                          }""");
    assert(is LinkedList<Object> r2 = deserialize<Object>(json));
    assert(exists r20=r2[0],
        r20==1);
    assert(is Identifiable r21=r2[1],
        r21===r2);
}

test
shared void rtEntry() {
    value a = 2->infinity;
    
    // with static type info
    variable value json = serialize(a, true);
    assertEquals(json, """{
                           "key": 2,
                           "item": "∞"
                          }""");
    value r = deserialize<Integer->Float>(json);
    assertEquals(r, a);
    
    // without static type info
    json = serialize<Object>(a, true);
    assertEquals(json, """{
                           "class": "ceylon.language::Entry<ceylon.language::Integer,ceylon.language::Float>",
                           "key": 2,
                           "item": "∞"
                          }""");
    value r2 = deserialize<Object>(json);
    assertEquals(r2, a);
}

test
shared void rtEntryAbbrev() {
    value a = 2->infinity;
    
    // with static type info
    variable value json = serialize(a, true);
    assertEquals(json, """{
                           "key": 2,
                           "item": "∞"
                          }""");
    value r = deserialize<Integer->Float>(json);
    assertEquals(r, a);
    
    // without static type info
    json = serialize<Object>(a, true);
    assertEquals(json, """{
                           "class": "ceylon.language::Entry<ceylon.language::Integer,ceylon.language::Float>",
                           "key": 2,
                           "item": "∞"
                          }""");
    value r2 = deserialize<Object>(json);
    assertEquals(r2, a);
}

test
shared void rtHashMap() {
    value a = HashMap{1->"foo", 2->infinity};
    
    // with static type info
    variable value json = serialize(a, true);
    print(json);
    value r = deserialize<HashMap<Integer,String|Float>>(json);
    assertEquals(r, a);
    
    // without static type info
    json = serialize<Object>(a, true);
    print(json);
    value r2 = deserialize<Object>(json);
    assertEquals(r2, a);
}

test
shared void rtInvoice() {
    variable value json = serialize(exampleInvoice, true);
    assertEquals(json,
        """{
            "bill": {
             "name": "Mr Pig",
             "address": {
              "lines": [
               "3 Pigs House",
               "The Farm"
              ],
              "postCode": "3PH"
             }
            },
            "deliver": {
             "name": "Mr Pig",
             "address": {
              "lines": [
               "3 Pigs House",
               "The Farm"
              ],
              "postCode": "3PH"
             }
            },
            "items": [
             {
              "product": {
               "sku": "123",
               "description": "Bag of sand",
               "unitPrice": 2.34,
               "salesTaxRate": 0.2
              },
              "quantity": 4.0
             },
             {
              "product": {
               "sku": "876",
               "description": "Bag of cement",
               "unitPrice": 3.57,
               "salesTaxRate": 0.2
              },
              "quantity": 1.0
             }
            ]
           }""");
    value i2 = deserialize<Invoice>(json);
    assertEquals(i2.bill.name, "Mr Pig");
    assertEquals(i2.bill.address.lines.size, 2);
    assert(exists ba1 = i2.bill.address.lines[0]);
    assert(exists ba2 = i2.bill.address.lines[1]);
    assertEquals(ba1, "3 Pigs House");
    assertEquals(ba2, "The Farm");
    assertEquals(i2.bill.address.postCode, "3PH");
    
    assertEquals(i2.deliver.name, "Mr Pig");
    assertEquals(i2.deliver.address.lines.size, 2);
    assert(exists bd1 = i2.deliver.address.lines[0]);
    assert(exists bd2 = i2.deliver.address.lines[1]);
    assertEquals(bd1, "3 Pigs House");
    assertEquals(bd2, "The Farm");
    assertEquals(i2.deliver.address.postCode, "3PH");
    
    value item1 = i2.items[0];
    assertEquals(item1.product.sku, "123");
    assertEquals(item1.product.description, "Bag of sand");
    assertEquals(item1.product.unitPrice, 2.34);
    assertEquals(item1.product.salesTaxRate, 0.2);
    assertEquals(item1.quantity, 4);
    
    assert(exists item2 = i2.items[1]);
    assertEquals(item2.product.sku, "876");
    assertEquals(item2.product.description, "Bag of cement");
    assertEquals(item2.product.unitPrice, 3.57);
    assertEquals(item2.product.salesTaxRate, 0.2);
    assertEquals(item2.quantity, 1.0);
}


/*

test
shared void rtCyclicLate() {
    fail("need to test this");
}

test
shared void rtCyclicVariable() {
    fail("need to test this");
}
 */

serializable class CollidingAttributeX() {
    String s = "non-shared";
    shared String capture() => s;
}
serializable class CollidingAttributeY() 
        extends CollidingAttributeX() {
    shared default String s = "shared";
}
serializable class CollidingAttributeZ(String s="distinct,non-shared") 
        extends CollidingAttributeY() {
    shared String capture2() => s;
    
}

serializable class CollidingAttributeA() 
        extends CollidingAttributeY() {
    shared actual String s = "tricksy";
    shared String capture3() => super.s;
    
}

test
shared void rtCollidingAttribute() {
    value cas = CollidingAttributeX();
    variable value json = serialize(cas, true);
    print(json);
    assertEquals{
        actual = json;
        expected = """{
                       "s": "non-shared"
                      }""";
    };
    json = serialize(CollidingAttributeY(), true);
    print(json);
    assertEquals{
        actual = json;
        expected = """{
                       "CollidingAttributeX.s": "non-shared",
                       "s": "shared"
                      }""";
    };
    json = serialize(CollidingAttributeZ(), true);
    print(json);
    assertEquals{
        actual = json;
        expected = """{
                       "CollidingAttributeX.s": "non-shared",
                       "s": "shared",
                       "CollidingAttributeZ.s": "distinct,non-shared"
                      }""";
    };
    json = serialize(CollidingAttributeA(), true);
    print(json);
    assertEquals{
        actual = json;
        expected = """{
                       "CollidingAttributeX.s": "non-shared",
                       "CollidingAttributeY.s": "shared",
                       "CollidingAttributeA.s": "tricksy"
                      }""";
    };
    
    value r = deserialize<CollidingAttributeZ>(json);
    assertEquals(r, cas);
}

class DateSerializer() satisfies StringSerializer<Date> {
    shared actual Date deserialise(String serialForm) {
        assert(exists r = parseDate(serialForm));
        return r;
    }
    
    shared actual String serialise(Date instance) {
        return instance.string;
    }
}

test
shared void rtDate() {
     Date d = date(2016, 9, 22);
     value v = Generic(d);
     
     try {
        serialize(v);
    } catch (SerializationException e){}
     
    value json = serialize {
        rootInstance = v;
        formatters=map{`Date`->DateSerializer()};
    };
    
    assertEquals(json, "");
}