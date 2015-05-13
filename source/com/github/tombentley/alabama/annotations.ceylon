import ceylon.language.meta.declaration {
    ValueDeclaration,
    ClassDeclaration,
    ConstructorDeclaration
}
import ceylon.language.meta {
    annotations
}
import ceylon.collection {
    HashMap,
    HashSet,
    ArrayList
}
shared final annotation class Key(key) 
        satisfies OptionalAnnotation<Key, ValueDeclaration>{
    shared String key;
}
"Specifies the name of the key used when writing and reading JSON."
see(`function aliasedKey`)
shared annotation Key key(String key) => Key(key);

shared final annotation class AliasedKey(key) 
        satisfies SequencedAnnotation<AliasedKey, ValueDeclaration>{
    shared String key;
}
"Specifies an alternative name for an attribute when reading JSON. 
 This can be useful to support attribute renaming while maintaining 
 compatibility with serialized data."
see(`function key`)
shared annotation AliasedKey aliasedKey(String name) => AliasedKey(name);

shared final annotation class Omitted() 
        satisfies OptionalAnnotation<Omitted, ValueDeclaration>{
}
"Annotates an attribute which should not be included when writing JSON."
see(`function ignoredKeys`)
shared annotation Omitted omittedAttribute() => Omitted();// unserializable? ignored? notWritten

shared final annotation class IgnoredKeys(keys) 
        satisfies OptionalAnnotation<IgnoredKeys, ClassDeclaration>{
    shared String[] keys;
}
"Lists keys to be ignored when reading JSON. A matching attribute will not be sought."
see(`function omittedAttribute`)
shared annotation IgnoredKeys ignoredKeys(String* keys) => IgnoredKeys(keys);

/*shared final annotation class LogicalName(name) 
        satisfies OptionalAnnotation<LogicalName, ClassDeclaration>{
    shared String name;
}
"Annotates a class to give itsh logical name. Used with [[LogicalTypeNaming]]."
shared annotation LogicalName logicalName(String name) => LogicalName(name);*/

shared final annotation class DeserializationConstructor() 
        satisfies OptionalAnnotation<DeserializationConstructor, ConstructorDeclaration>{
}
"Annotates the constructor to be used for deserialization."
see(`function ignoredKeys`)
shared annotation DeserializationConstructor deserialization() => DeserializationConstructor();

"Per-class configuration options"
shared class ClassSerialization(clazz, constructor, omittedAttributes, ignoredKeys, keys, memberizer) {
    
    "The class"
    shared ClassDeclaration clazz;
    "A means the instantiate the class"
    shared ClassDeclaration|ConstructorDeclaration constructor;
    
    
    "Attributes of the class which should not be included in the emitted JSON"
    shared Collection<ValueDeclaration> omittedAttributes;
    "Keys which should be ignored during deserialization (when reading JSON)."
    shared Collection<String> ignoredKeys;
    "A map from JSON key name to AttibuteSerialization. 
     A given AttibuteSerialization may be included more than once
     if it has alises."
    shared Map<String, AttibuteSerialization> keys;
    "How instances of the class should be serialized."
    shared Memberizer memberizer;

    String s<in Element>(Iterable<Element> c1, Iterable<Element> c2)
            given Element satisfies Object
        => ", ".join(HashSet{*c1} & HashSet{*c2});
    
    if (omittedAttributes.containsAny(keys.items)) {
        throw AssertionError("omitted attributes cannot also be keys: ``s(omittedAttributes, keys.items)``");
    }
    if (ignoredKeys.containsAny(keys.keys)) {
        throw AssertionError("ignored keys cannot also be keys: ``s(ignoredKeys, keys.keys)``");
    }
    
    // TODO check for dupe aliases and/or keys
}
"Per-attribute configuration options"
shared class AttibuteSerialization(attr, key, aliases) {
    "The attribute"
    shared ValueDeclaration attr;
    "The key used for this attribute when instances of the class are serialized as an object"
    shared String key;
    "Alternate names by which this attribute is known during deserialization."
    shared String[] aliases;
}

"Build an [[AttibuteSerialization]] according to the annotations on [[attr].]"
AttibuteSerialization readAttributes(ValueDeclaration attr) {
    String key;
    if (exists k = annotations(`Key`, attr)) {
        key = k.key;
    } else {
        key = attr.name;
    }
    String[] aliases;
    if (nonempty a = annotations(`AliasedKey`, attr)) {
        aliases = a*.key;
    } else {
        aliases = [];
    }
    
    return AttibuteSerialization(attr, key, aliases);
}

"Build a [[ClassSerialization]] according to the annotations on [[clazz].]"
ClassSerialization readClass(ClassDeclaration clazz, Memberizer memberizer) {
    String[] ignoredKeys;
    if (exists k = annotations(`IgnoredKeys`, clazz)) {
        ignoredKeys = k.keys;
    } else {
        ignoredKeys = [];
    }
    value keys = HashMap<String, AttibuteSerialization>();
    value omittedAttributes = HashSet<ValueDeclaration>();
    for (attr in clazz.memberDeclarations<ValueDeclaration>()) {// TODO inheritance
        value as = readAttributes(attr);
        if (exists other=keys.put(as.key, as)) {
            throw AssertionError("key ``as.key`` on ``as.attr``is also used as key/alias on ``other.attr``");
        }
        for (al in as.aliases) {
            if (exists other=keys.put(al, as)) {
                throw AssertionError("alias ``as.key`` on ``as.attr``is also used as key/alias on ``other.attr``");
            }
        }
        if (attr.annotated<Omitted>()) {
            omittedAttributes.add(attr);
        }
    }
    value ac = ArrayList<ConstructorDeclaration>();
    ClassDeclaration|ConstructorDeclaration constructor;
    for (ctor in clazz.constructorDeclarations()) {
        if (exists c=annotations(`DeserializationConstructor`, ctor)) {
            ac.add(ctor);
        }
    } 
    switch (size = ac.size)
    case(0) {
        constructor = clazz;
    }
    case(1) {
        assert(exists c=ac[0]);
        constructor = c;
    }
    else {
        throw AssertionError("multiple constructors annotated with deserialization");
    }
    return ClassSerialization(clazz, constructor, omittedAttributes, ignoredKeys, keys, memberizer);
}