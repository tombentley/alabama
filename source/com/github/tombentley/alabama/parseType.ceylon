import ceylon.language.meta {
    modules
}
import ceylon.language.meta.declaration {
    Module,
    Package,
    ClassOrInterfaceDeclaration,
    TypedDeclaration,
    AliasDeclaration,
    ValueDeclaration,
    FunctionDeclaration,
    NestableDeclaration
}
import ceylon.language.meta.model {
    Type,
    ClassOrInterface,
    InterfaceModel,
    ClassModel,
    nothingType,
    Model,
    Function,
    Class,
    ConstructorModel
}


"A token produced by a lexer"
class Token(shared Object type, shared String token, shared Integer index) {
    shared actual String string => "``token`` (``type``) at index ``index``";
}

"enumerates the different token types"
abstract class TokenType(shared actual String string)
        of dtAnd | dtOr | dtDot | dtComma | dtDColon | dtGt | dtLt 
        | dtDigit | dtUpper | dtLower | dtEoi {}

object dtAnd extends TokenType("&") {}
object dtOr extends TokenType("|") {}
object dtDot extends TokenType(".") {}
object dtComma extends TokenType(",") {}
object dtDColon extends TokenType("::") {}
object dtGt extends TokenType(">") {}
object dtLt extends TokenType("<") {}
object dtDigit extends TokenType("digit") {}
object dtUpper extends TokenType("upper") {}
object dtLower extends TokenType("lower") {}
object dtEoi extends TokenType("<eoi>") {}


"The tokenizer used by [[DatumParser]]."
class Tokenizer(input) {
    "The input stream that we're tokenizing."
    shared String input;
    
    "Our index into the input."
    variable value ii = 0;
    
    
    function ident(TokenType firstType, String firstChar, Integer start) {
        variable value pos = start;
        while (exists c = input[pos]) {
            if (c.letter || c.digit || c == '_') {
                pos++;
            } else {
                break;
            }
        }
        return Token(firstType, input[start:pos-start], start);
    }
    
    Token at(Integer index) {
        if (exists char = input[ii]) {
            switch (char)
            case ('&') {
                return Token(dtAnd, char.string, ii);
            }
            case ('|') {
                return Token(dtOr, char.string, ii);
            }
            case ('.') {
                return Token(dtDot, char.string, ii);
            }
            case (',') {
                return Token(dtComma, char.string, ii);
            }
            case ('<') {
                return Token(dtLt, char.string, ii);
            }
            case ('>') {
                return Token(dtGt, char.string, ii);
            }
            case (':') {
                // check next is also :
                if (exists char2 = input[ii + 1]) {
                    if (char2 == ':') {
                        return Token(dtDColon, input[ii:2], ii);
                    } else {
                        throw Exception("tokenization error, expected ::, not :``char2`` at index ``ii``");
                    }
                }
                throw Exception("unexpected end of input");
            }
            else {
                if ('0' <= char <= '9') {
                    return Token(dtDigit, char.string, ii);
                } else if (char.lowercase) {
                    return ident(dtLower, char.string, ii);
                } else if (char.uppercase) {
                    return ident(dtUpper, char.string, ii);
                } else if (char =="\\") {
                    if (exists char2 = input[ii + 1]) {
                        if (char2 == "I") {
                            return ident(dtUpper, char2.string, ii);
                        } else if (char2 == "i") {
                            return ident(dtLower, char2.string, ii);
                        } else {
                            throw Exception("tokenization error, expected \\i or \\I, not :\\``char2`` at index ``ii``");
                        }
                    }
                    throw Exception("unexpected end of input");
                }else {
                    throw Exception("unexpected character ``char`` at index ``ii``");
                }
            }
        } else {
            return Token(dtEoi, "", ii);
        }
    }
    
    variable Token current_ = at(0);
    
    "The current token."
    shared Token current {
        return current_;
    }
    
    "Return the current token, moving on to the next token."
    shared String consume() {
        value result = current.token;
        ii += current_.token.size;
        current_ = at(index);
        return result;
    }
    
    "The index of the current token in the input."
    shared Integer index => ii;
    
    "If the current token's type is the given type then consume the 
     token and return it. 
     Otherwise throw an [[AssertionError]]."
    shared String expect(TokenType type) {
        if (current.type == type) {
            return consume();
        } else {
            throw AssertionError("unexpected token: expected ``type``, found ``current``");
        }
    }
    
    "If the current token's type is the given type then consume and 
     discard the token and return true. 
     Otherwise return false."
    shared Boolean isType(TokenType type) {
        if (current.type == type) {
            consume();
            return true;
        } else {
            return false;
        }
    }
}

"""
   input ::= intersectionType ;
   intersectionType ::= unionType ('&' intersectionType) ;
   unionType ::= simpleType ('|' intersectionType) ;
   simpleType ::= declaration typeArguments? ('.' typeName typeArguments?)* ;
   declaration ::= packageName '::' typeName ;
   packageName ::= lident (. lident)* ;
   typeName ::= uident;
   typeArgments := '<' intersectionType (',' intersectionType)* '>';
   
   """
class TypeParser(String input) {
    
    value tokenizer = Tokenizer(input);
    
    """input ::= intersectionType ;"""
    shared Type parse() {
        value result = intersectionType();
        tokenizer.expect(dtEoi);
        return result;
    }
    
    """intersectionType ::= unionType ('&' intersectionType) ;"""
    Type intersectionType() {
        variable Type result = unionType();
        if (tokenizer.isType(dtAnd)) {
            Type u2 = unionType();
            result = result.intersection(u2);
        }
        return result;
    }
    
    """unionType ::= simpleType ('|' intersectionType) ;"""
    Type unionType() {
        variable Type result = simpleType();
        if (tokenizer.isType(dtOr)) {
            Type u2 = intersectionType();
            result = result.union(u2);
        }
        return result;
    }
    
    """simpleType ::= declaration typeArguments? ('.' typeName typeArguments?)* ;"""
    Type simpleType() {
        value d = declaration();
        Type[] ta;
        if (tokenizer.current.type == dtLt) {
            ta = typeArguments();
        } else {
            ta = [];
        }
        if (is ClassOrInterfaceDeclaration d) {
            variable ClassOrInterface x = d.apply<Anything>(*ta);
            while (tokenizer.isType(dtDot)) {
                value mt = typeName();
                value mta = typeArguments();
                assert(is ClassModel|InterfaceModel k = x.getClassOrInterface(mt, *mta));
                x = k;
            }
            return x;
        } else {
            assert(ta.empty,
                !tokenizer.isType(dtDot));
            return d;
        }
    }
    
    """declaration ::= packageName '::' typeName ;"""
    Type<Nothing>|ClassOrInterfaceDeclaration declaration() {
        Package p = packageName();
        tokenizer.expect(dtDColon);
        value t = typeName();
        if (exists r = p.getClassOrInterface(t)) {
            return r;
        } else {
            if (t == "Nothing"
                && p.name == "ceylon.language") {
                return nothingType;
            } else {
                throw AssertionError("type does not exist: ``t`` in ``p``" );
            }
        }
    }
    
    """typeArgments := '<' intersectionType (',' intersectionType)* '>';"""
    Type[] typeArguments() {
        tokenizer.expect(dtLt);
        variable Type[] result = [];
        while(true) {
            value t = intersectionType();
            result = result.withTrailing(t);
            if (!tokenizer.isType(dtComma)) {
                break;
            }
        }
        tokenizer.expect(dtGt);
        return result;
    }
    
    """typeName ::= uident;"""
    String typeName() {
        return tokenizer.expect(dtUpper);
    }
    
    """packageName ::= lident (. lident)* ;"""
    Package packageName() {
        variable Integer start = tokenizer.index;
        variable Module? mod = null;
        lident();
        while (true) {
            if (!mod exists) {
                value xx = tokenizer.input.measure(start, tokenizer.index-start);
                for (m in modules.list) {
                    if (m.name == xx) {
                        mod = m;
                        //start = tokenizer.index;
                        break;
                    }
                }
            }
            if (!tokenizer.isType(dtDot)) {
                break;
            }
            lident();
        }
        assert(exists m=mod);
        assert(exists p=m.findPackage(tokenizer.input.measure(start, tokenizer.index-start)));
        return p;
    }
    String? uident() {
        if (tokenizer.current.type == dtUpper) {
            value result = tokenizer.current.token;
            tokenizer.consume();
            return result;
        } else {
            return null;
        }
    }
    String? lident() {
        if (tokenizer.current.type == dtLower) {
            value result = tokenizer.current.token;
            tokenizer.consume();
            return result;
        } else {
            return null;
        }
    }
}

shared Type parseType(String t) => TypeParser(t).parse();



"""
   input ::= intersectionModel ;
   intersectionModel ::= unionModel ('&' intersectionModel) ;
   unionModel ::= qualifiedModel ('|' intersectionType) ;
   qualifiedModel ::= qualifiedDeclaration typeArguments? ('.' declarationName  typeArguments?)* ;
   qualifiedDeclaration ::= packageName '::' declarationName ;
   packageName ::= lident (. lident)* ;
   declarationName ::= typeName | memberName
   typeName ::= uident;
   memberName ::= lident;
   typeArgments := '<' intersectionType (',' intersectionType)* '>';
   
   """
class ModelParser() {
    value modulesList = modules.list;
    
    """input ::= intersectionType ;"""
    shared Model|Type|ConstructorModel parse(String input) {
        value tokenizer = Tokenizer(input);
        value result = intersectionModel(tokenizer);
        tokenizer.expect(dtEoi);
        return result;
    }
    
    """intersectionType ::= unionType ('&' intersectionType) ;"""
    Model|Type|ConstructorModel intersectionModel(Tokenizer tokenizer) {
        variable value result = unionModel(tokenizer);
        if (tokenizer.isType(dtAnd)) {
            assert(is Type u1=result);
            assert(is Type u2 = unionModel(tokenizer));
            result = u1.intersection(u2);
        }
        return result;
    }
    
    """unionType ::= simpleType ('|' intersectionType) ;"""
    Model|Type|ConstructorModel unionModel(Tokenizer tokenizer) {
        variable value result = qualifiedModel(tokenizer);
        if (tokenizer.isType(dtOr)) {
            assert(is Type u1=result);
            assert(is Type u2 = intersectionModel(tokenizer));
            result = u1.union(u2);
        }
        return result;
    }
    
    """qualifiedModel ::= qualifiedDeclaration typeArguments? ('.' declarationName  typeArguments?)* ;"""
    Model|Type|ConstructorModel qualifiedModel(Tokenizer tokenizer) {
        value d = declaration(tokenizer);
        Type[]? ta = typeArguments(tokenizer);
        if (is ClassOrInterfaceDeclaration d) {
            variable Model|Type|ConstructorModel result = d.apply<Anything>(*(ta else []));
            while (tokenizer.isType(dtDot)) {
                value m = declarationName(tokenizer);
                value mta = typeArguments(tokenizer);
                if (is ClassOrInterface container=result) {
                    if (is ClassOrInterface c = container.getClassOrInterface(m, *(mta else []))) {
                        result = c;
                    } else if (exists f=container.getMethod<Nothing,Anything,Nothing>(m, *(mta else []))) {
                        assert(tokenizer.isType(dtEoi));
                        result = f;
                    } else if (exists a=container.getAttribute<Nothing,Anything,Nothing>(m)) {
                        "attribute cannot have type arguments"
                        assert(! mta exists);
                        assert(tokenizer.isType(dtEoi));
                        result = a;
                    } else if (is Class c=container,
                        exists ct=c.getConstructor(m)) {
                        "constructor cannot have type arguments"
                        assert(! mta exists);
                        result = ct;
                    } else {
                        throw AssertionError("could not find ``m`` in ``container``");
                    }
                } else {
                    throw AssertionError("attempt to look up member ``m`` of ``result`` which is not a ClassOrInterface");
                }
            }
            return result;
        } else if (is FunctionDeclaration d){
            variable Function x = d.apply<Anything>(*(ta else []));
            return x;
        } else if (is ValueDeclaration d){
            "value cannot have type arguments"
            assert(! ta exists);
            return d.apply<Anything, Nothing>();
        } else if (is AliasDeclaration d) {
            // TODO
            throw AssertionError("not implemented yet");
        } else if (is Type<Nothing> d) {
            return d;
        } else {
            // SetterDeclaration should be impossible because they're accessed via the Getter
            // ConstructorDeclaration should be impossible because they don't occur at the top level
            assert(false);
        }
    }
    
    """qualifiedDeclaration ::= packageName '::' declarationName ;"""
    Type<Nothing>|TypedDeclaration declaration(Tokenizer tokenizer) {
        Package p = packageName(tokenizer);
        tokenizer.expect(dtDColon);
        value t = declarationName(tokenizer);
        if (exists r = p.getMember<NestableDeclaration>(t)) {
            /*if (is ClassDeclaration r,
                exists o=r.objectValue) {
                // find the value of an object declaration in preference to its class
                return o;
            }*/
            return r;
        } else {
            if (t == "Nothing"
                && p.name == "ceylon.language") {
                return nothingType;
            } else {
                throw AssertionError("type does not exist: ``t`` in ``p``" );
            }
        }
    }
    
    """typeArgments := '<' intersectionType (',' intersectionType)* '>';"""
    Type[]? typeArguments(Tokenizer tokenizer) {
        if (tokenizer.isType(dtLt)) {
            assert(is Type t1 = intersectionModel(tokenizer));
            variable Type[] result = [t1];
            while(tokenizer.isType(dtComma)) {
                value t2 = intersectionModel(tokenizer);
                assert(is Type t2);
                result = result.withTrailing(t2);
            }
            tokenizer.expect(dtGt);
            return result;
        } else {
            return null;
        }
    }
    
    """declarationName ::= typeName | memberName ;"""
    String declarationName(Tokenizer tokenizer) {
        if (tokenizer.current.type == dtUpper
            || tokenizer.current.type == dtLower) {
            return tokenizer.consume();
        } else {
            throw AssertionError("expected an identifier");
        }
    }
    
    """packageName ::= lident (. lident)* ;"""
    Package packageName(Tokenizer tokenizer) {
        variable Integer start = tokenizer.index;
        variable Module? mod = null;
        tokenizer.expect(dtLower);
        while (true) {
            if (!mod exists) {
                value xx = tokenizer.input.measure(start, tokenizer.index-start);
                for (m in modulesList) {
                    if (m.name == xx) {
                        mod = m;
                        //start = tokenizer.index;
                        break;
                    }
                }
            }
            if (!tokenizer.isType(dtDot)) {
                break;
            }
            tokenizer.expect(dtLower);
        }
        assert(exists m=mod);
        assert(exists p=m.findPackage(tokenizer.input.measure(start, tokenizer.index-start)));
        return p;
    }
}

Model|Type|ConstructorModel parseModel(String t) => ModelParser().parse(t);

shared void testParseModel() {
    assert(`String` == parseModel("ceylon.language::String"));
    assert(`Integer` == parseModel("ceylon.language::Integer"));
    assert(`Anything` == parseModel("ceylon.language::Anything"));
    assert(`Nothing` == parseModel("ceylon.language::Nothing"));
    assert(`true` == parseModel("ceylon.language::true"));
    assert(`false` == parseModel("ceylon.language::false"));
    assert(`null` == parseModel("ceylon.language::null"));
    assert(`nothing` == parseModel("ceylon.language::nothing"));
    assert(`empty` == parseModel("ceylon.language::empty"));
    assert(`print` == parseModel("ceylon.language::print"));
    assert(`String.size` == parseModel("ceylon.language::String.size"));
    assert(`String.endsWith` == parseModel("ceylon.language::String.endsWith"));
    assert(`List<String>.size` == parseModel("ceylon.language::List<ceylon.language::String>.size"));
    assert(`String|Integer` == parseModel("ceylon.language::String|ceylon.language::Integer"));
}