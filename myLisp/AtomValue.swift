//
//  AtomValue.swift
//  myLisp
//
//  Created by Francisco Gorina Vanrell on 18/8/24.
//

import Foundation
import Cocoa

enum AtomValueError: Error {
    case conversionError(String)
    case legthsNotEqual(String)
}

public enum AtomValue{
    case int (Int)
    case double (Double)
    case string (String)
    case boolean (Bool)
    case binary (Data?)
    case image (NSImage?)
    case object (UUID)
    case function (name: String, specialForm: Bool , f: (SExpr, Environment?, Int) -> SExpr)
    
    var doubleValue: Double {
        switch self{
            
        case .int(let v):
            return Double(v)
            
        case .double(let v):
            return v

        case .string(let v):
            return Double(v) ?? 0.0
            
        case .boolean(let v):
            return v ? 1.0 : 0.0
            
        case .binary(let data):
            if let data = data{
                return Double(data.count)
            }else {
                return 0.0
            }
        case .image(let data):
            if let data = data{
                return Double(data.size.height * data.size.width)
            }else {
                return 0.0
            }
        case .object(let uuid):
            return Double(Lisp.shared.getObject(uuid)?.count ?? 0)
            
        case .function:
            return 0.0
        }
            
    }
    
    var intValue: Int {
        switch self{
            
        case .int(let v):
            return v
            
        case .double(let v):
            if v < Double(Int.min) {
                return Int.min
            }else if v > Double(Int.max) {
                return Int.max
            } else {
                return Int(floor(v))
            }
            
        case .string(let v):
            return Int(v) ?? 0
            
        case .boolean(let v):
            return v ? 1 : 0
            
        case .binary(let data):
            if let data = data{
                return data.count
            }else {
                return 0
            }
        case .image(let data):
            if let data = data{
                return Int(data.size.height * data.size.width)
            }else {
                return 0
            }
        case .object(let uuid):
            return Lisp.shared.getObject(uuid)?.count ?? 0
            
        case .function:
            return 0
        }
    }

    var stringValue: String {
        switch self{
            
        case .int(let v):
            return String(v)
            
        case .double(let v):
            return String(v)
            
        case .string(let v):
            return v
            
        case .boolean(let v):
            return v ? "true" : "false"
            
        case .binary(let data):
            if let data = data {
                if let str  = String(data: data, encoding: .utf8){
                    return str
                }else{
                    return "Binary data \(data.count) bytes"
                }
            }else{
                return "Empty binary data"
            }
        case .image(let data):
            
            if let data = data{
                return "Image \(data.size.width) by \(data.size.height) pixels"
            }else {
                return "Empty image"
            }
        case .object(let uuid):
            if let obj = Lisp.shared.getObject(uuid){
                return obj.fields.map { field in
                    if let value = obj.valueFor(field){
                        if let objvalue = value.objectValue{
                            return "\(field): \(objvalue.id) \(objvalue.valueFor("name") ?? "")"
                        }else{
                            return "\(field): \(value.stringValue)"
                        }
                    }else{
                        return ""
                    }
                }.joined(separator: "\n")
            }else{
                return ""
            }
             
        case .function(let name, _, _):
            return "\(name)"
        }
        

    }
    
    var booleanValue: Bool {
        switch self{
            
        case .int(let v):
            return v != 0
            
        case .double(let v):
            return abs(v) >= 1.0

        case .string(let v):
            return v != "false" && !v.isEmpty
            
        case .boolean(let v):
            return v

        case .binary(let data):
            return data != nil
        case .image(let data):
            return data != nil
            
        case .object(let uuid):
            return (Lisp.shared.getObject(uuid)?.count ?? 0) != 0
            
        case .function:
            return true
        }
    }
    
    var uuidValue : UUID? {
        switch self{
        case .object (let uuid):
            return uuid
        default:
            return nil
        }
    }

    var functionValue :  ((SExpr, Environment?, Int) -> SExpr)? {
        switch self {
        case let .function(name: _, specialForm: _, f: f):
            return f
            
        default:
            return  nil
        }
    }
    var isFunction : Bool {
        return functionValue != nil
    }
    var isObject : Bool {
       return uuidValue != nil
    }
    
    
    func getFieldValue(_ field : String, context: Environment? ) -> SExpr?{
        switch self{
        case .object(let uuid):
            
            if let o = Lisp.shared.getObject(uuid){
                if let v = o.valueFor(field){
                    switch v {
                    case .Atom(_):
                        return v //v.eval(with: context, level: 0)!.1
                    default:
                        return v //.eval(with: context, level: 0)!.1
                    }
                }
                else if let lnk = o.valueFor("kind-of"){
                    let s = lnk.eval(with: context, level: 0)
                    if let r = s?.1{
                        switch r {
                        case .Atom(let v):
                            if v.isObject {
                                return v.getFieldValue(field, context: context)
                            }
                        default:
                            break
                        }
                    }
                 }
            }
        default:
            break
        }
        return nil
    }
}

extension AtomValue : Equatable {
    public static func ==(lhs: AtomValue, rhs: AtomValue) -> Bool{
        switch(lhs,rhs){
        case let (.int(l),.int(r)):
            return l==r
            
        case let (.double(l),.double(r)):
            return abs(l - r) < 0.000001
            
        case let (.string(l),.string(r)):
            return l==r
            
        case let (.boolean(l),.boolean(r)):
            return l==r
            
        case let (.binary(l), .binary(r)):
            return l == r
            
        case let (.object(d1), .object(d2)):
            return d1 == d2
            
        case (.function(let name1, _, _), .function(let name2, _, _)):
            return name1 == name2
        default:
            return false
        }
    }
}

extension AtomValue : CustomStringConvertible{
    public var description: String {
        switch self{
        case let .int(value):
            return "(Int) \(value)"
        case let .double(value):
            return "(Double) \(value)"
        case let .string(value):
            return "\(value)"
        case let .boolean(value):
            return value ? "true" : "false"
        case let .binary(value):
            if let data = value {
                return "\(data.count) bytes"
            }else{
                return "Empty data"
            }
        case .image(let data):
            
            if let data = data{
                return "Image \(data.size.width) by \(data.size.height) pixels"
            }else {
                return "Empty image"
            }
        case  let .object(uuid):
            let obj = Lisp.shared.getObject(uuid)
            return "Object \(uuid) References \(obj?.references ?? -1)\n \(self.stringValue)"
            
        case .function(let name, _, _):
            return name
        }
    }
    func prettyPrint(prefix: String) -> String {
        switch self{
        case .object(let uuid):
            if let obj = Lisp.shared.getObject(uuid){
                var str = "\(prefix)Object \(uuid) References \(obj.references)\n"
                for field in obj.fields {
                    if let value = obj.valueFor(field){
                        if let v = value.objectValue {
                            str = str + prefix + "\(field) : \(v.id)  \(v.valueFor("name") ?? "")\n"
                        }else {
                            str = str + prefix + field + ":" + value.prettyPrint(prefix: prefix+"    ")+"\n"
                        }
                    }
                }
                return str
                
            }else{
                return "\(prefix)Object \(uuid) does not exist"
            }
            
        default:
            return prefix + description
            
        }
        
    }
    
    
}

extension AtomValue : ExpressibleByStringLiteral,ExpressibleByUnicodeScalarLiteral,ExpressibleByExtendedGraphemeClusterLiteral {
    
    public init(_ value : String){
        self = .string(value)
    }
    
    public init(_ value : Double){
        self = .double(value)
    }
    
    public init(_ value : Int){
        self = .int(value)
    }
    
    public init(_ value : Bool){
        self = .boolean(value)
    }
    
    public init(_ value : Data){
        self = .binary(value)
    }
    
    public init(_ value : NSImage){
        self = .image(value)
    }
    
    public init(_ value : Dictionary<String, SExpr>){
        let o = LispObject(data : value)
        Lisp.shared.addObject(o)
        self = .object(o.id)
    }
    
    public init(stringLiteral value: String){
        if let v = Int(value){
            self = .int(v)
        }
        else if let v = Double(value){
            self = .double(v)
        }else if let v = Bool(value){
            self = .boolean(v)
        }
        else{
            self = .string(value)
        }
    }
    

    public init(extendedGraphemeClusterLiteral value: String){
        self.init(stringLiteral: value)
    }
    
    public init(unicodeScalarLiteral value: String){
        self.init(stringLiteral: value)
    }
        
}
