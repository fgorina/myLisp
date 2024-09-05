/**
 *  SwiftyLisp
 *
 *  Copyright (c) 2016 Umberto Raimondi. Licensed under the MIT license, as follows:
 *
 *  Permission is hereby granted, free of charge, to any person obtaining a copy
 *  of this software and associated documentation files (the "Software"), to deal
 *  in the Software without restriction, including without limitation the rights
 *  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 *  copies of the Software, and to permit persons to whom the Software is
 *  furnished to do so, subject to the following conditions:
 *
 *  The above copyright notice and this permission notice shall be included in all
 *  copies or substantial portions of the Software.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 *  SOFTWARE.
 */

import Foundation

/**
 Recursive Enum used to represent symbolic expressions for this LISP.
 
 Create a new evaluable symbolic expression with a string literal:
 
 let sexpr: SExpr = "(car (quote (a b c d e)))"
 
 Or call explicitly the `read(sexpr:)` method:
 
 let myexpression = "(car (quote (a b c d e)))"
 let sexpr = SExpr.read(myexpression)
 
 And evaluate it in the default environment (where the LISP builtins are registered) using the `eval()` method:
 
 print(sexpr.eval()) // Prints the "a" atom
 
 The default builtins are: quote,car,cdr,cons,equal,atom,cond,lambda,label,defun.
 
 Additionally the expression can be evaluated in a custom environment with a different set of named functions that
 trasform an input S-Expression in an output S-Expression:
 
 let myenv: [String: (SExpr)->SExpr] = ...
 print(sexpr.eval(myenv))
 
 The default environment is available through the global constant `defaultEnvironment`
 
 */
enum LispError: Error {
    case conversionError(String)
    case legthsNotEqual(String)
}

public class Environment {
    
    private var variables = [String: SExpr]()
    private var _previousContext : Environment?
    private var _level = 0
    
    var previousContext : Environment? {
        return _previousContext
    }
    var isTopContext : Bool {
        return previousContext == nil
    }
    
    var level : Int {
        return _level
    }
    
    var keys : [String] {
        return Array(variables.keys)
    }
    
    init(_ pc : Environment?, values : Dictionary<String, SExpr>? = nil) {
    
        self._previousContext = pc
        if let pc = pc {
            self._level = pc.level + 1
        }
        if let values = values {
            self.variables = values
        }
    }
    
    deinit {
        for (_, value) in variables {
            value.removeReferences()
          }
    }
    
    
    func topContext() -> Environment{
        var context : Environment = self
        
        while !context.isTopContext{
            context = context.previousContext!
        }
        
        return context
        
    }
    func lookupFunction(symbol : String) -> (parent: SExpr?, name: String, specialForm: Bool , f: (SExpr, Environment?, Int) -> SExpr)? {
        
        if let (parent, sexpr) = lookup(symbol){
            guard case let .Atom(value) = sexpr else {return nil}
            guard case let .function(name, specialForm, f) = value else {return nil}
            return (parent, name, specialForm, f)
            
        } else if let context = previousContext {
            return context.lookupFunction(symbol: symbol)
        }else{
            return nil
        }
    }
    
    func lookup(_ s : String) -> (parent: SExpr?, object: SExpr)?{
  
        var path : [String] = [s]
        
        if s.contains("."){
            path = s.split(separator: ".").map({ x in
                String(x)
            })
         }
        if path.isEmpty {
            path = [s]
        }
        var f : SExpr? = nil
        
        if var o  = variables[path[0]] {
            if path.count <= 1{
                return (f, o)
            }else{
                for item in path.dropFirst(){
                    f = o
                    switch f {
                    case .Atom(let v):
                        if v.isObject {
                            if let x = v.getFieldValue(item, context: self){
                                o = x
                            }else{
                                return (f, .snull)
                            }
                        }
                    default:
                        return (nil, f!)
                    }
                  }
                 
                return (f, o)
            }
        } else if let context = previousContext {
            return context.lookup(s)
        }else{
            return nil
        }
    }
    
    
    func lookupObject(_ s : String) -> (Environment, LispObject)?{
        if let o = variables[s] {
            if let v = o.objectValue{
                return (self, v)
            }else{
                //fputs("lookupObject : Object \(s) is not an object.", stderr)
                return nil
            }
            
        }else if let context = previousContext {
            return context.lookupObject(s)
        }else{
            return nil
        }
    }

    
/*    func lookupFieldValue(o : Dictionary<String : SExpr>, field: String){
        
        
        
        
    }
 */
    func put(symbol: String, specialForm : Bool = false, value: @escaping ((SExpr, Environment?, Int) -> SExpr)){
        let atom = SExpr.Atom(.function(name: symbol, specialForm: specialForm, f: value))
        if let (_, trace) = self.lookup("trace"){
            if( !trace.isNull()){
                fputs("Adding \(symbol) to environment \(self.level) with value \(String(describing: value))\n", stderr)
            }
        }
        self.put(name: symbol, value: atom)
    }

    func put(name: String, value: SExpr){
        variables[name] = value
        if let obj = value.objectValue{
            obj.incRef()
        }
    }
    
    func simplePut(name: String, value: SExpr){ // Before Lisp is inited
        variables[name] = value
    }
    
    func putGlobal(symbol: String, specialForm : Bool = false, value: @escaping ((SExpr, Environment?, Int) -> SExpr)){
        let atom = SExpr.Atom(.function(name: symbol, specialForm: specialForm, f: value))
        if let (_, trace) = self.lookup("trace"){
            if( !trace.isNull()){
                fputs("Adding \(symbol) to environment \(self.level) with value \(String(describing: value))\n", stderr)
            }
        }
        self.putGlobal(name: symbol, value: atom)
    }

    func putGlobal(name: String, value: SExpr) {
        let top = topContext()
        top.put(name: name, value: value)

    }
    
    func removeGlobal(name: String) {
        let top = topContext()
        let value = top.lookupObject(name)?.1
        top.variables.removeValue(forKey: name)
        if let obj = value {
            obj.decRef()
            if obj.references <= 0 {
                Lisp.shared.removeObject(obj.id)
            }
        }
    }
    
    func remove(name: String){
        
        if let (_, obj) = lookupObject(name){
            obj.decRef()
            if obj.references <= 0 {
                Lisp.shared.removeObject(obj.id)
            }
        }
        variables.removeValue(forKey: name)
    }
}

public class LispObject {
    
    var _id : UUID
    private var _data : Dictionary<String, SExpr> = [:]
    private var _references = 0
    
     
    init(_ id: UUID = UUID(), data: Dictionary<String, SExpr> = [:]){
        self._id = id
        self._data = data
        
        for key in _data.keys {
            if let obj = data[key]?.objectValue {
                obj.incRef()
            }
        }
    }
    
    convenience init?(_ str : String, data: Dictionary<String, SExpr> = [:]){
        if let id = UUID(uuidString: str){
            self.init(id, data: data)
        }else{
            return nil
        }
    }
    
    var count : Int {
        _data.count
    }
    
    var fields : [String] {
        _data.keys.map { s in
            s
        }
    }
    
    var id : UUID {
        return _id
    }
    
    var references : Int {
        return _references
    }
    var description : String {
        return "Object \(_id) Refs: \(references)\n" + fields.map { field in
            if let value = valueFor(field){
                return "    \(field): \(value.stringValue)"
            }else{
                return "    "
            }
        }.joined(separator: "\n") + "\n"
    }
    func valueFor(_ field : String) -> SExpr? {
        if let v = _data[field]{
            return v
        }else{
            return nil
        }
    }
    func setValueFor(_ field: String, value: SExpr){
        if let obj = _data[field]?.objectValue {
            obj.decRef()
            if obj.references <= 0{
                Lisp.shared.removeObject(obj.id)
            }
        }
        
        if value.isNull(){
            _data.removeValue(forKey: field)
        }else{
            _data[field] = value
            
            if let obj = value.objectValue{
                obj.incRef()
            }
        }
    }
    
    func incRef(){
        _references += 1
    }
    
    func decRef(){
        _references = max(0, _references-1)
    }
    
    
}

public class Lisp {
    
    /// Basic builtins

    static var shared = Lisp()
    
    var context : Environment = Environment(nil)
    var expression : SExpr?
    var trace : Bool = false
    private var heap : Dictionary<UUID, LispObject> = [:]
    
    private init(){
        context.put(name: "trace", value: .snull)
    }
    
    func process(lines : [String]) {
        var buffer : String = ""
        for s in lines {
            if s.hasPrefix(";"){
                
            }else{
                buffer += s
                if isCompleted(s: buffer) && !buffer.isEmpty{
                    _ = Lisp.shared.eval(s: buffer)
                    buffer = ""
                }
            }
        }
    }


    func eval(s: String) -> SExpr?{
        let expr : SExpr = SExpr(stringLiteral: s)
        return expr.eval(with: context, level: 0)?.1
    }
    
    func addObject(_ o : LispObject){
        heap[o.id] = o
    }
    
    func removeObject(_ id: UUID){
        if let obj = getObject(id){
            for field in obj.fields{
                if let obj1 = obj.valueFor(field)?.objectValue {
                    obj1.decRef()
                    if obj1.references <= 0{
                        Lisp.shared.removeObject(obj1.id)
                    }
                }
            }
        }
        heap.removeValue(forKey: id)
    }
    
    func getObject(_ id: UUID) -> LispObject?{
        heap[id]
    }
    
    func objectUUIDs() -> [UUID]{
        return heap.keys.map { uuid in
            uuid
        }
    }
}




