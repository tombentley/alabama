import com.github.tombentley.alabama {
    deserialize,
    serialize
}
import ceylon.test {
    assertEquals,
    test,
    assertTrue,
    fail
}
import ceylon.language.meta {
    type
}
import ceylon.collection {
    ArrayList,
    LinkedList,
    HashMap
}

test
shared void rtEmptyArray() {
    // with static type info
    variable Array<Integer> a = Array<Integer>{};
    variable value json = serialize(a, false);
    assertEquals(json, """[]""");
    variable value a2 = deserialize<Array<Anything>>(json);
    assertEquals(a2.size, 0);
    assert(! a2[0] exists);
    
    // without static type info
    a = Array<Integer>{};
    json = serialize<Object>(a, false);
    assertEquals(json, """{"class":"ceylon.language::Array<ceylon.language::Integer>","value":[]}""");
    value a3 = deserialize<Object>(json);
    assert(is Array<Integer> a3);
    assertEquals(a3.size, 0);
    assert(! a3[0] exists);
}

test
shared void rtArray() {
    // with static type info
    variable Array<Integer> a = Array<Integer>{1,2,3};
    variable value json = serialize(a, false);
    assertEquals(json, """[1,2,3]""");
    value a2 = deserialize<Array<Anything>>(json);
    assertEquals(a2.size, 3);
    assert(exists a20=a2[0], a20 == 1);
    assert(exists a21=a2[1], a21 == 2);
    assert(exists a22=a2[2], a22 == 3);
    
    // without static type info
    json = serialize<Object>(a, false);
    assertEquals(json, """{"class":"ceylon.language::Array<ceylon.language::Integer>","value":[1,2,3]}""");
    value a3 = deserialize<Object>(json);
    assert(is Array<Integer> a3);
    assertEquals(a3.size, 3);
    assert(exists a30=a2[0], a30 == 1);
    assert(exists a31=a2[1], a31 == 2);
    assert(exists a32=a2[2], a32 == 3);
}

test
shared void rtCyclicArray() {
    // with static type info
    Array<Anything> l = Array<Anything>.ofSize(1, null);
    l.set(0, l);
    variable value json = serialize(l, false);
    assertEquals(json, """{"#":1,"value":[{"@":1}]}""");
    variable value y = deserialize<Array<Anything>>(json);
    assert(is Identifiable x=y[0], x === y); 
    
    // without static type info
    json = serialize(l of Object, false);
    assertEquals(json, """{"class":"ceylon.language::Array<ceylon.language::Anything>","#":1,"value":[{"@":1}]}""");
    value y2 = deserialize<Object>(json);
    assert(is Array<Anything> y2);
    assert(is Identifiable x2=y2[0], x2 === y2);
}


test
shared void rtTuple() {
    value tuple1 = [1, "2", true];
    variable value json = serialize(tuple1, false);
    assertEquals(json, """[1,"2",true]""");
    assertEquals {
        actual = deserialize<[Integer, String, Boolean]>(json);  
        expected = tuple1; 
    };
    
    json = serialize([Generic("S")], false);
    assertEquals(json, """[{"element":"S"}]""");
    assertEquals { 
        actual = deserialize<[Generic<String>]>(json)[0].element; 
        expected = "S"; 
    };
    
    json = serialize(Generic(tuple1), false);
    assertEquals(json, """{"element":[1,"2",true]}""");
    assertEquals { 
        actual = deserialize<Generic<[Integer, String, Boolean]>>(json).element; 
        expected = tuple1;
    };
    
    // TODO support tuple type abbrevs
    // tests where the deserializer doesn't know the expected type
    json = serialize<Object>(tuple1, false);
    assertEquals(json, """{"class":"ceylon.language::Tuple<ceylon.language::true|ceylon.language::String|ceylon.language::Integer,ceylon.language::Integer,ceylon.language::Tuple<ceylon.language::true|ceylon.language::String,ceylon.language::String,ceylon.language::Tuple<ceylon.language::true,ceylon.language::true,ceylon.language::empty>>>","value":[1,"2",true]}""");
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
    assertEquals(json, """{"class":"test.com.github.tombentley.alabama::Generic<ceylon.language::Tuple<ceylon.language::Integer|ceylon.language::String|ceylon.language::Boolean,ceylon.language::Integer,ceylon.language::Tuple<ceylon.language::String|ceylon.language::Boolean,ceylon.language::String,ceylon.language::Tuple<ceylon.language::Boolean,ceylon.language::Boolean,ceylon.language::Empty>>>>","element":[1,"2",true]}""");
    assert(is Generic<[Integer, String, Boolean]> got2 = deserialize<Object>(json));
    assertEquals { 
        actual = got2.element; 
        expected = tuple1; 
    };
}
test
shared void rtTupleWithRest() {
    value tuple = [1, "2", true, *(4..6)];
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
    
    // TODO In this case all I actually need to know from the wrapper class
    // is that the JSON array is a Tuple (I don't need the tuple instantiation)
    // because the reification of tuple uses the runtime types
    json = serialize(tuple of Object, true);
    assertEquals{
        expected = """{
                       "class": "ceylon.language::Tuple<ceylon.language::Integer|ceylon.language::String|ceylon.language::true,ceylon.language::Integer,ceylon.language::Tuple<ceylon.language::Integer|ceylon.language::String|ceylon.language::true,ceylon.language::String,ceylon.language::Tuple<ceylon.language::Integer|ceylon.language::true,ceylon.language::true,ceylon.language::Span<ceylon.language::Integer>>>>",
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
    assert(is ArraySequence<Anything> as = (Array{1, "2", true}.sequence() of Object));
    variable value json = serialize(as);
    assertEquals(json, """[1,"2",true]""");
    assert(is ArraySequence<Anything> as2 = deserialize<Anything>(json));
    assert(as2 == as);
    
    json = serialize(Generic(as));
    assertEquals(json, """{"element":[1,"2",true]}""");
    value as3 = deserialize<Generic<ArraySequence<Anything>>>(json);
    assert(as3.element == as);
}


// TODO a non-serializable class
// TODO getting the right type info for attributes, and elements

test
shared void rtString() {
    variable String json = serialize("hello, world");
    assertEquals(json, """"hello, world"""");
    assertEquals(deserialize<String>(json), "hello, world");
    
    json = serialize("hello, world" of Object);
    assertEquals(json, """"hello, world"""");
    assertEquals(deserialize<Object>(json), "hello, world");
    
    json = serialize("hello, world" of String?);
    assertEquals(json, """"hello, world"""");
    assertEquals(deserialize<String?>(json), "hello, world");
}

test
shared void rtInteger() {
    variable String json = serialize(42);
    assertEquals(json, """42""");
    assertEquals(deserialize<Integer>(json), 42);
    
    json = serialize(42 of Object);
    assertEquals(json, """42""");
    assertEquals(deserialize<Object>(json), 42);
}

test
shared void rtFloat() {
    variable String json = serialize(42.5);
    assertEquals(json, """42.5""");
    assertEquals(deserialize<Float>(json), 42.5);
    
    json = serialize(42.5 of Object);
    assertEquals(json, """42.5""");
    assertEquals(deserialize<Object>(json), 42.5);
}

test
shared void rtMinusZero() {
    variable String json = serialize(-0.0);
    assertEquals(json, """-0.0""");
    value got = deserialize<Float>(json);
    assertEquals(got, -0.0);
    assertTrue(got.strictlyNegative);
    
}

test
shared void rtNaN() {
    variable String json = serialize(0.0/0.0);
    assertEquals(json, """{"value":"NaN"}""");
    assertTrue(deserialize<Float>(json).undefined);
    
    json = serialize<Object>(0.0/0.0);
    assertEquals(json, """{"class":"ceylon.language::Float","value":"NaN"}""");
    assertTrue(deserialize<Float>(json).undefined);
}

test
shared void rtInfinity() {
    value infinity = 1.0/0.0;
    variable String json = serialize(infinity);
    assertEquals(json, """{"value":"∞"}""");
    assertEquals(deserialize<Float>(json), infinity);
    
    json = serialize<Object>(infinity);
    assertEquals(json, """{"class":"ceylon.language::Float","value":"∞"}""");
    assertEquals(deserialize<Float>(json), infinity);
    
    json = serialize(-infinity);
    assertEquals(json, """{"value":"-∞"}""");
    assertEquals(deserialize<Float>(json), -infinity);
    
    json = serialize<Object>(-infinity);
    assertEquals(json, """{"class":"ceylon.language::Float","value":"-∞"}""");
    assertEquals(deserialize<Float>(json), -infinity);
    
    json = serialize([infinity]);
    assertEquals(json, """[{"value":"∞"}]""");
    assertEquals(deserialize<[Float]>(json), [infinity]);
    
    json = serialize<Object>([infinity]);
    assertEquals(json, """{"class":"ceylon.language::Tuple<ceylon.language::Float,ceylon.language::Float,ceylon.language::empty>","value":[{"class":"ceylon.language::Float","value":"∞"}]}""");
    assertEquals(deserialize<Object>(json), [infinity]);
    
}

test
shared void rtBoolean() {
    variable String json = serialize(true);
    assertEquals(json, """true""");
    assertEquals(deserialize<Boolean>(json), true);
    
    json = serialize(true of Object);
    assertEquals(json, """true""");
    assertEquals(deserialize<Object>(json), true);
}

test
shared void rtNull() {
    variable String json = serialize(null);
    assertEquals(json, """null""");
    assertEquals(deserialize<Anything>(json), null);
    
    json = serialize(null of String?);
    assertEquals(json, """null""");
    assertEquals(deserialize<String?>(json), null);
}

test
shared void rtCharacter() {
    variable String json = serialize('x');
    assertEquals(json, """"x"""");
    assertEquals(deserialize<Character>(json), 'x');
    
    json = serialize<Object>('x' of Object);
    assertEquals(json, """{"class":"ceylon.language::Character","value":"x"}""");
    assertEquals(deserialize<Object>(json), 'x');
}


test
shared void rtEmpty() {
    variable String json = serialize([]);
    assertEquals(json, """{"class":"ceylon.language::empty"}""");
    assertEquals(deserialize<[]>(json), []);
    
    json = serialize<Object>([]);
    assertEquals(json, """{"class":"ceylon.language::empty"}""");
    assertEquals(deserialize<Object>(json), []);
}

test
shared void rtLarger() {
    variable String json = serialize(larger);
    assertEquals(json, """{"class":"ceylon.language::larger"}""");
    assertEquals(deserialize<\Ilarger>(json), larger);
    assertEquals(deserialize<Comparison>(json), larger);
    
    json = serialize(larger of Object);
    assertEquals(json, """{"class":"ceylon.language::larger"}""");
    assertEquals(deserialize<Object>(json), larger);
}

serializable class StringContainer(string) {
    shared actual String string;
}

test
shared void rtStringContainer() {
    variable String json = serialize(StringContainer("hello, world"));
    assertEquals(json, """{"string":"hello, world"}""");
    assertEquals(deserialize<StringContainer>(json).string, "hello, world");
    
    json = serialize(StringContainer("hello, world") of Object);
    assertEquals(json, """{"class":"test.com.github.tombentley.alabama::StringContainer","string":"hello, world"}""");
    assertEquals(deserialize<Object>(json).string, "hello, world");
}

test
shared void rtGenericString() {
    variable String json = serialize(Generic("hello, world"));
    assertEquals(json, """{"element":"hello, world"}""");
    assertEquals(deserialize<Generic<String>>(json).element, "hello, world");
    
    json = serialize(Generic("hello, world") of Object);
    assertEquals(json, """{"class":"test.com.github.tombentley.alabama::Generic<ceylon.language::String>","element":"hello, world"}""");
    assert(is Generic<String> o = deserialize<Object>(json));
    assertEquals(o.element, "hello, world");
}

test
shared void rtGenericOptionalString() {
    variable String json = serialize(Generic<String?>("hello, world"));
    assertEquals(json, """{"element":"hello, world"}""");
    assertEquals(deserialize<Generic<String?>>(json).element, "hello, world");
    
    json = serialize(Generic<String?>(null));
    assertEquals(json, """{"element":null}""");
    assertEquals(deserialize<Generic<String?>>(json).element, null);
    
    json = serialize(Generic<String?>("hello, world") of Object);
    assertEquals(json, """{"class":"test.com.github.tombentley.alabama::Generic<ceylon.language::Null|ceylon.language::String>","element":"hello, world"}""");
    assert(is Generic<String?> o = deserialize<Object>(json));
    assertEquals(o.element, "hello, world");
    
    json = serialize(Generic<String?>(null) of Object);
    assertEquals(json, """{"class":"test.com.github.tombentley.alabama::Generic<ceylon.language::Null|ceylon.language::String>","element":null}""");
    assert(is Generic<String?> o2 = deserialize<Object>(json));
    assertEquals(o2.element, null);
}

test
shared void rtGenericCharacter() {
    variable String json = serialize(Generic('x'));
    assertEquals(json, """{"element":"x"}""");
    assertEquals(deserialize<Generic<Character>>(json).element, 'x');
    
    json = serialize(Generic('x') of Object);
    assertEquals(json, """{"class":"test.com.github.tombentley.alabama::Generic<ceylon.language::Character>","element":"x"}""");
    assert(is Generic<Character> o = deserialize<Object>(json));
    assertEquals(o.element, 'x');
}

test
shared void rtGenericEmpty() {
    variable String json = serialize(Generic([] of String[]));
    assertEquals(json, """{"element":{"class":"ceylon.language::empty"}}""");
    assertEquals(deserialize<Generic<String[]>>(json).element, []);
    
    json = serialize(Generic([] of String[]) of Object);
    assertEquals(json, """{"class":"test.com.github.tombentley.alabama::Generic<ceylon.language::Sequential<ceylon.language::String>>","element":{"class":"ceylon.language::empty"}}""");
    assert(is Generic<String[]> o = deserialize<Object>(json));
    assertEquals(o.element, []);
}

test
shared void rtGenericLarger() {
    variable String json = serialize(Generic(larger));
    assertEquals(json, """{"element":{"class":"ceylon.language::larger"}}""");
    assertEquals(deserialize<Generic<Comparison>>(json).element, larger);
    
    json = serialize(Generic(larger) of Object);
    assertEquals(json, """{"class":"test.com.github.tombentley.alabama::Generic<ceylon.language::Comparison>","element":{"class":"ceylon.language::larger"}}""");
    assert(is Generic<Comparison> o = deserialize<Object>(json));
    assertEquals(o.element, larger);
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
}
test
shared void rtDiamond() {
    Zero zero = Zero();
    One left = One(zero);
    One right = One(zero);
    Two top = Two(left, right);
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
    
    fail("need deserialisation assertions");
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
    // with static type info
    value a = LinkedList{1, "foo", true};
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
    // with static type info
    value a = LinkedList<Object>{1};
    a.add(a);
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
    // with static type info
    value a = [1->"foo", 2->infinity, 3->'z'];
    variable value json = serialize(a, true);
    print(json);
    value r = deserialize<[Integer->String, Integer->Float, Integer->Character]>(json);
    assertEquals(r, a);
}

test
shared void rtHashMap() {
    // with static type info
    value a = HashMap{1->"foo", 2->infinity};
    variable value json = serialize(a, true);
    print(json);
    value r = deserialize<HashMap<Integer,String|Float>>(json);
    assertEquals(r, a);
}

/*

test
shared void rtInvoice() {
    fail("need to test this");
}

test
shared void rtHashMap() {
    fail("need to test this");
}

test
shared void rtCyclicLate() {
    fail("need to test this");
}

test
shared void rtCyclicVariable() {
    fail("need to test this");
}

test
shared void rtCollidingAttribute() {
    fail("need to test this");
}
*/