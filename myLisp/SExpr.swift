//
//  SExpr.swift
//  myLisp
//
//  Created by Francisco Gorina Vanrell on 18/8/24.
//

import Foundation

public enum SExpr{
    case Atom(AtomValue) // Era String
    case List([SExpr])
    
    
    static let snull = SExpr.List([])
    static let strue = SExpr.Atom(.string("true"))
    
    var stringValue : String {
        switch self {
        case .Atom(let v):
            return v.stringValue
            
        case .List(let l):
            if l.isEmpty{
                return ""
            }
            else{
                return l[0].stringValue + " " + SExpr.List(Array(l.dropFirst())).stringValue
            }
        }
    }
    
    var uuidValue : UUID?{
        guard case let .Atom(value) = self  else {return nil}
        return value.uuidValue
    }
    
    var objectValue : LispObject? {
        if let uuid = self.uuidValue {
            if let o = Lisp.shared.getObject(uuid){
                return o
            } else {
                fputs("objectValue : Object \(uuid) is not found.", stderr)
                return nil
            }
        }
        return nil
    }
    
    public func removeReferences(){
        switch self{
             case .Atom(let value):
                switch value{
                case .object(let uuid):
                    if let obj = Lisp.shared.getObject(uuid){
                        obj.decRef()
                        if obj.references <= 0{
                            Lisp.shared.removeObject(uuid)
                        }
                    }
                default:
                    break
                }
            case .List(let l):
            for expr in l {
                expr.removeReferences()
            }
        }
    }
    
    public func isNull() -> Bool{
        
        switch self {
        case .Atom(_):
            return false
            
        case .List(let p):
            return p.isEmpty
        }
    }
    
    public func isFalse() -> Bool{
        
        switch self {
        case .Atom(let v):
            return !v.booleanValue
             
        case .List(let p):
            return p.isEmpty
        }
    }
    
    public func isTrue() -> Bool{
       return !isFalse()
    }
    /**
     Evaluates this SExpression with the given functions environment
     
     - Parameter environment: A set of named functions or the default environment
     - Returns: the resulting SExpression after evaluation
     */
    public func eval(with context: Environment? = nil,  level : Int) -> (SExpr?, SExpr?)?{
        var node = self
        
        let trace = !evaluateVariable(.Atom(.string("trace")), with: context).1.isNull()
        let levelSpaces = StringLiteralType(repeating: " ", count: level)
        
        if trace {
            fputs("\(levelSpaces)Evaluating \(self.description)\n", stderr)
            
        }
        
        switch node {
        case .Atom:
            let (parent, r) =  evaluateVariable(node, with: context)
            if trace {fputs("\(levelSpaces)Evaluating Atom \(self.description) => \(r.description)\n", stderr)}
            return (parent, r)
            
        case let  .List(elements):
          
            var localContext : Environment?
            
            guard elements.count > 0 else {return (nil, self)} // Empty lists have nothing to evaluate
        
            var fullElements : [(SExpr?, SExpr?)] = elements.map { s in
                (nil as SExpr?, s)
            }
            // Evaluate all subexpressions
  
          
            if fullElements.count > 0  {
                var skipEval = false
                if case let .Atom(value) = elements[0] {
                    let form = (localContext ?? context)?.lookupFunction(symbol: value.stringValue)
                    skipEval = form?.specialForm ?? false
                }
                
                var first = true
               // if !skipEval {
                    localContext = Environment(context)
                
                    fullElements = fullElements.map{
                        if first || !skipEval {
                            let r = $0.1!.eval(with: localContext,  level: level+1)!
                            first = false
                            return r
                            
                        }else{
                            return $0
                        }
                    }
               // }else{
               //
               // }
            }
            // We must lookup function because it may have been changed by the evaluation !!! (case of functions and lambdas)
            node = .List(fullElements.map({ v in
                v.1!
            }))
            if elements.count > 0, case let .Atom(value) = fullElements[0].1{
                
                if value.isFunction {
                    if let parent = fullElements[0].0 {
                        localContext?.put(name: "self", value: parent)
                    }
                    let r = value.functionValue?(node, localContext ?? context, level) ?? .snull
                    
                    if trace {fputs("\(levelSpaces)Evaluating \(self.description) => \(r.description)\n", stderr)}
                    return (nil, r)
                }else{
                    if let form = (localContext ?? context)?.lookupFunction(symbol: value.stringValue){
                        if let parent = form.parent {
                            localContext?.put(name: "self", value: parent)
                        }
                        let r = form.f(node, localContext ?? context, level)
                        
                        if trace {fputs("\(levelSpaces)Evaluating \(self.description) => \(r.description)\n", stderr)}
                        return(form.parent, r)
                    }
                }
            }

            if trace{fputs("\(levelSpaces)Evaluating \(self.description) => \(node.description)\n", stderr)}
            return (nil, node)
        }
    }
    
    private func evaluateVariable(_ v: SExpr, with context: Environment?) -> (SExpr?, SExpr) {
        guard let context = context else {return (nil, v)}
        
        guard case let .Atom(lname) = v else {return (nil, .snull)}
        
        if let (parent, val) = context.lookup(lname.stringValue){
            return (parent, val)
        }else{
            return (nil, v)
        }
    }
}

//MARK: Equatable
/// Extension that implements a recursive Equatable, needed for the equal atom
///
extension SExpr : Equatable {
    public static func ==(lhs: SExpr, rhs: SExpr) -> Bool{
        switch(lhs,rhs){
        case let (.Atom(l),.Atom(r)):
            return l==r
        case let (.List(l),.List(r)):
            guard l.count == r.count else {return false}
            for (idx,el) in l.enumerated() {
                if el != r[idx] {
                    return false
                }
            }
            return true
        default:
            return false
        }
    }
    

}

//MARK: CustomStringConvertible
/// Extension that implements CustomStringConvertible to pretty-print the S-Expression
extension SExpr : CustomStringConvertible{
    public var description: String {
        switch self{
        case let .Atom(value):
            if value.stringValue.contains(" "){
                return "\"\(value.description)\" "
            }else{
                return "\(value.description) "
            }
        case let .List(subxexprs):
            var res = "("
            for expr in subxexprs{
                res += "\(expr) "
            }
            res += ")"
            return res
        }
    }
    
    func prettyPrint(prefix: String) -> String {
        switch self{
        case let .Atom(value):
            if value.stringValue.contains(" "){
                return "\"\(value.prettyPrint(prefix: prefix))\" "
            }else{
                return "\(value.prettyPrint(prefix: prefix)) "
            }
        case let .List(subxexprs):
            var res = "("
            for expr in subxexprs{
                res += "\(expr.prettyPrint(prefix: "")) "
            }
            res += ")"
            return res
        }
    }
    
}

//MARK: ExpressibleByStringLiteral
/// Extension needed to convert string literals to a SExpr
extension SExpr : ExpressibleByStringLiteral,ExpressibleByUnicodeScalarLiteral,ExpressibleByExtendedGraphemeClusterLiteral {
    
    public init(stringLiteral value: String){
        self = SExpr.read(value)
    }
    
    public init(extendedGraphemeClusterLiteral value: String){
        self.init(stringLiteral: value)
    }
    
    public init(unicodeScalarLiteral value: String){
        self.init(stringLiteral: value)
    }
    
}

//MARK: Parsing
/// Read, Tokenize and parsing extension
extension SExpr {
    
    /**
     Read a LISP string and convert it to a hierarchical S-Expression
     */
    public static func read(_ sexpr:String) -> SExpr{
        
        enum Token{
            case pOpen,pClose,textBlock(String)
        }
        
        /**
         Break down a string to a series of tokens
         
         - Parameter sexpr: Stringified S-Expression
         - Returns: Series of tokens
         */
        func tokenize(_ sexpr:String) -> [Token] {
            var res = [Token]()
            var tmpText = ""
            
            var literal = false
            var escape = false
            
            for c in sexpr {
                if escape {
                    tmpText.append(c)
                    escape = false
                } else if c == "\\"{
                    escape = true
                }else if literal && c != "\""{
                    tmpText.append(c)
                }else{
                   
                        switch c {
                        
                        case "(":
                            if tmpText != "" {
                                res.append(.textBlock(tmpText))
                                tmpText = ""
                            }
                            res.append(.pOpen)
                        case ")":
                            if tmpText != "" {
                                res.append(.textBlock(tmpText))
                                tmpText = ""
                            }
                            res.append(.pClose)
                        case " ":
                            if tmpText != "" {
                                res.append(.textBlock(tmpText))
                                tmpText = ""
                            }
                            
                        case "\"":
                            
                            if literal {
                                res.append(.textBlock(tmpText))
                                tmpText = ""
                            }
                            literal.toggle()
                            
                        default:
                            tmpText.append(c)
                        }
                    
                }
            }
            
            if !tmpText.isEmpty{
                res.append(.textBlock(tmpText))
            }
            
            return res
        }
        
        func appendTo(list: SExpr?, node:SExpr) -> SExpr {
            var list = list
            
            if list != nil, case var .List(elements) = list! {
                elements.append(node)
                list = .List(elements)
            }else{
                list = node
            }
            return list!
        }
        
        /**
         Parses a series of tokens to obtain a hierachical S-Expression
         
         - Parameter tokens: Tokens to parse
         - Parameter node: Parent S-Expression if available
         
         - Returns: Tuple with remaning tokens and resulting S-Expression
         */
        func parse(_ tokens: [Token], node: SExpr? = nil) -> (remaining:[Token], subexpr:SExpr?) {
            var tokens = tokens
            var node = node
            
            if tokens.isEmpty{
                return (remaining:[], subexpr: nil)
            }
            var i = 0
            repeat {
                
                if i >= tokens.count {
                    return (remaining:[], subexpr: node) // Was nil
                }
                let t = tokens[i]
                
                switch t {
                case .pOpen:
                    //new sexpr
                    let (tr,n) = parse( Array(tokens[(i+1)..<tokens.count]), node: .snull)
                    assert(n != nil) //Cannot be nil
                    
                    (tokens, i) = (tr, 0)
                    node = appendTo(list: node, node: n!)
                    
                    if tokens.count != 0 {
                        continue
                    }else{
                        break
                    }
                case .pClose:
                    //close sexpr
                    return ( Array(tokens[(i+1)..<tokens.count]), node)
                case let .textBlock(value):
                    
                    node = appendTo(list: node, node: .Atom(AtomValue(stringLiteral: value)))
                }
                i += 1
            }while(tokens.count > 0)
            
            return (remaining: [], subexpr: node)
        }
        
        let tokens = tokenize(sexpr.replacingOccurrences(of: "\n", with: ""))
        let res = parse(tokens)
        return res.subexpr ?? .snull
    }
}

//MARK: Double Array
extension SExpr {
  
    func doubleArray()  throws -> [Double]{
        switch self {
        case .Atom(let v):
            return [v.doubleValue]
            
        case .List(let l):
            return try l.map { v in
                switch v {
                case .Atom(let v1):
                    return v1.doubleValue
                    
                case .List(_):
                    throw LispError.conversionError( "Only vectors may be conveted to double arrays")
                }
            }
        }
    }
    
    init(_ arr : [Double]) {
 
            self = .List(arr.map({ d in
                    .Atom(.double(d))
            }))
    }
    
    func vadd(_ s : SExpr) -> SExpr {
        do{
            let v1 = try self.doubleArray()
            let v2 = try s.doubleArray()
            let result = try v1.add(v2)
            return SExpr(result)
        }catch {
            return .snull
        }
    }
    func vsubtract(_ s : SExpr) -> SExpr {
        do{
            let v1 = try self.doubleArray()
            let v2 = try s.doubleArray()
            let result = try v1.subtract(v2)
            return SExpr(result)
        }catch {
            return .snull
        }
    }
    func vdot(_ s : SExpr) -> SExpr {
        do{
            let v1 = try self.doubleArray()
            let v2 = try s.doubleArray()
            let result = try v1.dot(v2)
            return .Atom(.double(result))
        }catch {
            return .snull
        }
    }

    func vcross(_ s : SExpr) -> SExpr {
        do{
            let v1 = try self.doubleArray()
            let v2 = try s.doubleArray()
            let result = try v1.cross(v2)
            return SExpr(result)
        }catch {
            return .snull
        }
    }
    
    func vmultiply(_ v : Double) -> SExpr {
        do{
            let v1 = try self.doubleArray()
     
            let result = v1.multiply(v)
            return SExpr(result)
        }catch {
            return .snull
        }
    }
    
}

//MARK: [Double]

extension [Double]{
    
    func dot ( _ v2: [Double]) throws -> Double{
        guard self.count == v2.count else {throw LispError.legthsNotEqual("Dot product needs 2 vectors of same length")}
        
        return zip(self, v2).reduce(0.0){
            $0 + $1.0*$1.1
        }
    }
    
    
    func add ( _ v2: [Double]) throws -> [Double]{
        guard self.count == v2.count else {throw LispError.legthsNotEqual("Add needs 2 vectors of same length")}
        
        return zip(self, v2).map { i1, i2 in
            i1 + i2
        }
    }
    
    func subtract ( _ v2: [Double]) throws -> [Double]{
        guard self.count == v2.count else {throw LispError.legthsNotEqual("Subtract needs 2 vectors of same length")}
        
        return zip(self, v2).map { i1, i2 in
            i1 - i2
        }
    }
    
    func cross ( _ v: [Double]) throws -> [Double]{
        guard self.count == v.count else {throw LispError.legthsNotEqual("Cross product needs 2 vectors of same length")}
        
        let u = self
        
        return [u[1]*v[2]-u[2]*v[1],
                u[2]*v[0]-u[0]*v[2],
                u[0]*v[1]-u[1]*v[0]
        ]
    }
    
    func multiply(_ v : Double) -> [Double]{
        
        return self.map { d in
            d * v
        }
    }
}
