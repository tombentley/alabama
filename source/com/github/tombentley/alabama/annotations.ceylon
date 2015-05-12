import ceylon.language.meta.declaration {
    ValueDeclaration,
    ClassDeclaration,
    ConstructorDeclaration
}
shared final annotation class Key(key) 
        satisfies OptionalAnnotation<Key, ValueDeclaration>{
    shared String key;
}
"Specifies the name of the key used when writing and reading JSON."
see(`function aliased`)
shared annotation Key key(String key) => Key(key);

shared final annotation class Aliased(key) 
        satisfies OptionalAnnotation<Aliased, ValueDeclaration>{
    shared String key;
}
"Specifies an alternative name for an attribute when reading JSON. 
 This can be useful to support attribute renaming while maintaining 
 compatibility with serialized data."
see(`function key`)
shared annotation Aliased aliased(String name) => Aliased(name);

shared final annotation class Omitted() 
        satisfies OptionalAnnotation<Omitted, ValueDeclaration>{
}
"Annotates an attribute which should not be included when writing JSON."
see(`function ignoredKeys`)
shared annotation Omitted omitted() => Omitted();// unserializable? ignored? notWritten

shared final annotation class IgnoredKeys(keys) 
        satisfies OptionalAnnotation<IgnoredKeys, ClassDeclaration>{
    shared String[] keys;
}
"Lists keys to be ignored when reading JSON. A matching attribute will not be sought."
see(`function omitted`)
shared annotation IgnoredKeys ignoredKeys(String* keys) => IgnoredKeys(keys);

shared final annotation class LogicalName(name) 
        satisfies OptionalAnnotation<LogicalName, ClassDeclaration>{
    shared String name;
}
"Annotates a class to give itsh logical name. Used with [[LogicalTypeNaming]]."
shared annotation LogicalName logicalName(String name) => LogicalName(name);

logicalName("Example")
ignoredKeys("gee")
class Ex(bar, baz) {
    key("foo")
    aliased("fooble")
    shared String bar;
    
    omitted
    shared String baz;
}

shared final annotation class PreferredConstructor() 
        satisfies OptionalAnnotation<PreferredConstructor, ConstructorDeclaration>{
}
"Annotates the constructor to be used for deserialization."
see(`function ignoredKeys`)
shared annotation PreferredConstructor preferredConstructor() => PreferredConstructor();