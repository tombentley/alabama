import ceylon.language.meta.model {
    ClassModel
}
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
"Annotates an attribute which should not be included when writing JSON.
 
 Omitting an attribute genererally means the JSON won't be deserializable
 using the [[Deserializer]], but can be useful when working with other 
 consumers of the JSON."
see(`function ignoredKeys`)
shared annotation Omitted omittedAttribute() => Omitted();// unserializable? ignored? notWritten

shared final annotation class Included() 
        satisfies OptionalAnnotation<Included, ValueDeclaration>{
}
"Annotates a non-reference (i.e. getter) attribute which should be 
 included when writing JSON.
 
 A non-reference attribute is not needed to reconstruct 
 the instance's state 
 (thus would usually also be included in [[ignoredKeys]]),
 but can be useful when dealing with other consumers of the JSON."
see(`function ignoredKeys`)
shared annotation Included includedAttribute() => Included();

shared final annotation class IgnoredKeys(keys) 
        satisfies OptionalAnnotation<IgnoredKeys, ClassDeclaration>{
    shared String[] keys;
}

shared final annotation class Identifier() 
        satisfies OptionalAnnotation<Identifier, ValueDeclaration>{
}
"Annotates an attribute which forms part of the classes identifier, 
 when a class has an explicit identifier"
shared annotation Identifier identifier() => Identifier();


shared final annotation class Discriminator() 
        satisfies OptionalAnnotation<Discriminator, ValueDeclaration>{
}
"Annotates an attribute which forms part of the classes discriminator, 
 when a class has an explicit discriminator."
shared annotation Discriminator discriminator() => Discriminator();

"Lists keys to be ignored when reading JSON. A matching attribute will not be sought."
see(`function omittedAttribute`)
shared annotation IgnoredKeys ignoredKeys(String* keys) => IgnoredKeys(keys);


"Per-class configuration options"
shared class ClassSerialization(clazz, omittedAttributes, ignoredKeys, keys) {
    
    "The class"
    shared ClassDeclaration clazz;
    
    "Attributes of the class which should not be included in the emitted JSON"
    shared Collection<ValueDeclaration> omittedAttributes;
    "Keys which should be ignored during deserialization (when reading JSON)."
    shared Collection<String> ignoredKeys;
    "A map from JSON key name to AttibuteSerialization. 
     A given AttibuteSerialization may be included more than once
     if it has aliases."
    shared Map<String, AttibuteSerialization> keys;
    
     value m = HashMap<ValueDeclaration, AttibuteSerialization>();
     for (as in keys.items) {
         m.put(as.attr, as);
     }
    shared Map<ValueDeclaration, AttibuteSerialization> byAttribute = m;
    String pretty<in Element>(Iterable<Element> c1, Iterable<Element> c2)
            given Element satisfies Object
        => ", ".join(HashSet{*c1} & HashSet{*c2});
    
    if (omittedAttributes.containsAny(keys.items)) {
        throw AssertionError("omitted attributes cannot also be keys: ``pretty(omittedAttributes, keys.items)``");
    }
    if (ignoredKeys.containsAny(keys.keys)) {
        throw AssertionError("ignored keys cannot also be keys: ``pretty(ignoredKeys, keys.keys)``");
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


shared class Config(
    {<ClassDeclaration->ClassSerialization>*} clas=[]) {
    //HashMap<ValueDeclaration, AttibuteSerialization> attributes = HashMap<ValueDeclaration, AttibuteSerialization>{*attrs};
    HashMap<ClassDeclaration, ClassSerialization> classes = HashMap<ClassDeclaration, ClassSerialization>{*clas};
    
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
    ClassSerialization readClass(ClassDeclaration clazz) {
        String[] ignoredKeys;
        if (exists k = annotations(`IgnoredKeys`, clazz)) {
            ignoredKeys = k.keys;
        } else {
            ignoredKeys = [];
        }
        value keys = HashMap<String, AttibuteSerialization>();
        value omittedAttributes = HashSet<ValueDeclaration>();
        for (attr in clazz.declaredMemberDeclarations<ValueDeclaration>()) {// TODO inheritance
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
        return ClassSerialization(clazz, omittedAttributes, ignoredKeys, keys);
    }
    
    
    "get the configuration for the given attribute"
    shared AttibuteSerialization? attribute(ValueDeclaration a) {
        if (is ClassDeclaration c=a.container) {
            return clazz(c).byAttribute[a];
        }
        return null;
    }
    
    "Get the configuration for the given class"
    shared ClassSerialization clazz(ClassDeclaration c) {
       if (exists cs = classes[c]) {
           return cs;
       } else {
           value cs = readClass(c);
           classes.put(c, cs);
           return cs;
       }
    }
    
    shared AttibuteSerialization? resolveKey(ClassModel clazz, String key) {
        variable ClassDeclaration? cd = clazz.declaration;
        while (exists c=cd) {
            value k = this.clazz(c).keys[key];
            if (exists k) {
                return k;
            }
            cd = c.extendedType?.declaration;
        }
        return null;
    }
}