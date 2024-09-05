//
//  InbuiltFunctions.swift
//  myLisp
//
//  Created by Francisco Gorina Vanrell on 11/8/24.
//

import Foundation
import Cocoa

extension Lisp {
    internal enum Builtins:String{
        case quote,car,cdr,cons,reversed,transposed,equal="=",atomp,intp,doublep,stringp, booleanp,
             cond,lambda,defun,specialform, list,eval,progn,setq,set, removeq, remove, run, map, reduce, compact,
             print, println, printenv,
             add="+",multiply="*",subtract="-",divide="/",mod,abs,
             sin, cos, tan, asin, acos, atan, atan2, sqr, sqrt, p2r, r2p,
             exp, ln, pwr, floor, explode, implode, concat, count, item, replaceItem, split,
             greater=">", lesser="<", greaterOrEqual=">=", lesserOrEqual="<=",
             not, and, or, pwd, cd, ls, home, read, write, get, post,
             urlscheme, urlpath, urlextension, urlhost, urlport,
             runprocess,
             vadd, vsubtract, vdot, vcross, vmultiply,
             hasprefix, hassuffix, contains, matches,
             fget, fset, object
 
    }
     

    func initContext(){
        context.putGlobal(symbol: Builtins.run.rawValue, specialForm: true, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 2 else {return .snull}
            guard case let .Atom(lname) = parameters[1] else {return .snull}
            let path = lname.stringValue
            do {
                let data = try String(contentsOfFile: path, encoding: .utf8)
                let myStrings = data.components(separatedBy: .newlines)
                Lisp.shared.process(lines: myStrings)
                fputs("Executed \(path)", stderr)
            } catch {
                print(error)
            }

            return .snull
        })
        
        //MARK: Basic List
        context.putGlobal(symbol: Builtins.quote.rawValue, specialForm: true, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 2 else {return .snull}
            return parameters[1]
        })
        
        
        context.putGlobal(symbol: Builtins.car.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 2 else {return .snull}
            guard case let .List(elements) = parameters[1], elements.count > 0 else {return .snull}
            return elements.first!
        })
        
        context.putGlobal(symbol: Builtins.cdr.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 2 else {return .snull}
            guard case let .List(elements) = parameters[1], elements.count > 1 else {return .snull}
            return .List(Array(elements.dropFirst(1)))
        })
        
        context.putGlobal(symbol: Builtins.cons.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 3 else {return .snull}
            
            guard case .List(let elRight) = parameters[2] else {return .snull}
            
            switch parameters[1].eval(with: context, level: level+1)!.1!{
            case let .Atom(p):
                return .List([.Atom(p)]+elRight)
            case let .List(l):
                return .List([.List(l)]+elRight)

            }
        })
        
        context.putGlobal(symbol: Builtins.reversed.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 2 else {return .snull}
            
            guard case .List(let l) = parameters[1] else {return .snull}
            
            let rl = Array(l.reversed())
            return .List(rl)
        })
        
        context.putGlobal(symbol: Builtins.transposed.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 2 else {return .snull}
            
            guard case .List(let l) = parameters[1] else {return .snull}
            
            guard case  .List( let row0) = l[0] else {return .snull}
            
            var arr : [[SExpr]] = Array(repeating: Array(repeating: SExpr.Atom(.int(0)), count: l.count), count: row0.count)
            
            let rows = l.count
      
            
            for i in 0..<rows{
                guard case  .List( let someRow) = l[i] else {return .snull}
                for j in 0..<someRow.count{
                    arr[j][i] = someRow[j]
                }
            }
           
            let list: [SExpr] = arr.map({ row in
                SExpr.List(row)
            })
           
            return .List(list)
        })
        
        context.putGlobal(symbol: Builtins.equal.rawValue, value: { params, context, level in
            guard case let .List(elements) = params, elements.count == 3 else {return .snull}
            
            let me = (context?.lookupFunction(symbol: Builtins.equal.rawValue)!.f)!
            let v1 = elements[1] //.eval(with: context,  level: level+1)!.1
            let v2 = elements[2] //.eval(with: context,  level: level+1)!.1
            switch (v1, v2) {
            case (.Atom(let elLeft),.Atom(let elRight)):
                return elLeft == elRight ? .strue : .snull
            case (.List(let elLeft),.List(let elRight)):
                guard elLeft.count == elRight.count else {return .snull}
                for (idx,el) in elLeft.enumerated() {
                    let testeq:[SExpr] = [.Atom(.string("Equal")),el,elRight[idx]]
                    if me(.List(testeq), context, level) != SExpr.strue {
                        return .snull
                    }
                }
                return .strue
            default:
                return .snull
            }
        })
        

        
        context.putGlobal(symbol: Builtins.cond.rawValue, specialForm: true, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count > 1 else {return .snull}
            
            for el in parameters.dropFirst(1) {
                guard case let .List(c) = el, c.count == 2 else {return .snull}
                
                if c[0].eval(with: context,  level: level+1)?.1?.isTrue() ?? false {
                    let res = c[1].eval(with: context,  level: level+1)
                    return res!.1!
                }
            }
            return .snull
        })
        
        //MARK: Iterators map, reduce, compact,
        
        context.putGlobal(symbol: Builtins.map.rawValue, specialForm: false, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 3 else {return .snull}
            
            guard case let .Atom(lname) = parameters[1], let f = lname.functionValue else {return .snull}
            guard case let .List(vars) = parameters[2] else {return .snull}
            
            let transformedList = vars.map { item in
                f(.List([parameters[1], item]), context, level+1)
            }
            return .List(transformedList)
        })
        
        context.putGlobal(symbol: Builtins.reduce.rawValue, specialForm: false, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 4 else {return .snull}
            
            guard case let .Atom(lname) = parameters[1], let f = lname.functionValue else {return .snull}
            guard case let .List(vars) = parameters[3] else {return .snull}
            
            let acum : SExpr = vars.reduce(parameters[2]) { partialResult, value in
                f(.List([parameters[1], partialResult, value]), context, level+1)
            }
           
            return acum
        })

        context.putGlobal(symbol: Builtins.compact.rawValue, specialForm: false, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 2 else {return .snull}
            
            guard case let .List(vars) = parameters[1] else {return .snull}
            
            let result = vars.filter { expr in
                !expr.isNull()
            }
            
           
            return .List(result)
        })

        
        
        context.putGlobal(symbol: Builtins.defun.rawValue, specialForm: true, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 4 else {return .snull}
            
            guard case let .Atom(lname) = parameters[1] else {return .snull}
            guard case let .List(vars) = parameters[2] else {return .snull}
            
            let lambda = parameters[3]
            
            let f: (SExpr, Environment?, Int)->SExpr = { params, ctx, levelx in
                guard case var .List(p) = params else {return .snull}
                p = Array(p.dropFirst(1))
                
                // Replace parameters in the lambda with values
                let localCtx = Environment(ctx)
                
                for (v, val) in zip(vars, p){
                    
                    if case let .Atom(vname) = v {
                        localCtx.put(name: vname.description, value: val)
                    }
                }
                
                if let result = lambda.eval(with: localCtx,  level: levelx+1){
                    return result.1 ?? .snull
                }else{
                    return .snull
                }
            }
            
            context?.putGlobal(symbol: lname.description, value: f)
            return .snull
        })
        
        context.putGlobal(symbol: Builtins.specialform.rawValue, specialForm: true, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 4 else {return .snull}
            
            guard case let .Atom(lname) = parameters[1] else {return .snull}
            guard case let .List(vars) = parameters[2] else {return .snull}
            
            let lambda = parameters[3]
            
            let f: (SExpr, Environment?, Int)->SExpr = { params, ctx, levelx in
                guard case var .List(p) = params else {return .snull}
                p = Array(p.dropFirst(1))
                
                // Replace parameters in the lambda with values
                let localCtx = Environment(ctx)
                
                for (v, val) in zip(vars, p){
                    
                    if case let .Atom(vname) = v {
                        localCtx.put(name: vname.description, value:val)
                    }
                }
                
                if let result = lambda.eval(with: localCtx,  level: levelx+1){
                    return result.1 ?? .snull
                }else{
                    return .snull
                }
            }
            
            context?.putGlobal(symbol: lname.description, specialForm: true, value: f)
            return .snull
        })

        
        context.putGlobal(symbol: Builtins.lambda.rawValue, specialForm: true, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 3 else {return .snull}
            
            guard case let .List(vars) = parameters[1] else {return .snull}
            let lambda = parameters[2]
            //Assign a name for this temporary closure
            let fname = "TMP$"+String(arc4random_uniform(UInt32.max))
            
            let f: (SExpr, Environment?, Int)->SExpr = { params,ctx, levelx in
                guard case var .List(p) = params else {return .snull}
                p = Array(p.dropFirst(1))
                
                // Replace parameters in the lambda with values
                
                
                let localCtx = Environment(ctx)
                for (v, val) in zip(vars, p){
                    
                    if case let .Atom(vname) = v {
                        localCtx.put(name: vname.description, value: val)
                    }
                }
                if let result = lambda.eval(with:localCtx,  level: levelx+1){
                    
                    return result.1 ?? .snull
                }else{
                    return .snull
                }
            }
            
            context?.put(symbol: fname, specialForm: false, value: f)
            return(.Atom(.function(name: fname, specialForm: false, f: f)))
            //return .snull
        })
        
        context.putGlobal(symbol: Builtins.progn.rawValue, specialForm: true, value: { params, context, level in
            guard case let .List(parameters) = params else {return .snull}
            
            
            let localCtx = Environment(context)
            var result : SExpr?
            
            for expr in parameters[1...] {
                (_, result) = expr.eval(with: localCtx,  level: level+1)!
            }
            
            return(result ?? .snull)
            
        })
        
        context.putGlobal(symbol: Builtins.list.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count > 1 else {return .snull}
            var res: [SExpr] = []
            
            for el in parameters.dropFirst(1) {
                switch el {
                case .Atom:
                    res.append(el)
                case let .List(els):
                    res.append(contentsOf: els)
                }
            }
            return .List(res)
        })
        context.putGlobal(symbol: Builtins.print.rawValue, specialForm: true, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count > 1 else {return .snull}
            
            let s = parameters[1].eval(with: context,  level: level+1)!
            
            fputs(s.1!.description, stdout)
            return s.1!
        })

        context.putGlobal(symbol: Builtins.println.rawValue, specialForm: true, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count > 1 else {return .snull}
            
            let s = parameters[1].eval(with: context,  level: level+1)!
            fputs("\(s.1!.prettyPrint(prefix: ""))\n", stdout)
            return s.1 ?? .snull
        })
        
        context.putGlobal(symbol: Builtins.eval.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 2 else {return .snull}
            
            return parameters[1].eval(with: context,  level: level+1)!.1 ?? .snull
        })
        
        context.putGlobal(symbol: Builtins.setq.rawValue, specialForm: true, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 3 else {return .snull}
            guard case let .Atom(lname) = parameters[1] else {return .snull}
            
            let localContext = Environment(context)
            let value = parameters[2].eval(with: localContext,  level: level+1)?.1 ?? .snull
            context?.putGlobal(name: lname.stringValue, value: value)

            return value
        })
        
        context.putGlobal(symbol: Builtins.set.rawValue, specialForm: true, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 3 else {return .snull}
            guard case let .Atom(lname) = parameters[1] else {return .snull}
            
            let value = parameters[2].eval(with: context,  level: level+1)?.1 ?? .snull
            if let ctx = context?.previousContext {
                ctx.put(name: lname.description, value: value)
            }else{
                context?.put(name: lname.description, value: value)
            }
            
            return value
        })
        context.putGlobal(symbol: Builtins.removeq.rawValue, specialForm: true, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 2 else {return .snull}
            guard case let .Atom(lname) = parameters[1] else {return .snull}
                    
            context?.removeGlobal(name: lname.stringValue)
            
            return .snull
        })
        
        context.putGlobal(symbol: Builtins.remove.rawValue, specialForm: true, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 2 else {return .snull}
            guard case let .Atom(lname) = parameters[1] else {return .snull}
            
            
            if let ctx = context?.previousContext {
                ctx.remove(name: lname.description)
            }else{
                context?.remove(name: lname.description)
            }
            return .snull
        })
        

        //MARK: Predicates
        context.putGlobal(symbol: Builtins.atomp.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 2 else {return .snull}
            
            switch parameters[1].eval(with: context,  level: level+1)!.1! {
            case .Atom:
                return .strue
            default:
                return .snull
            }
        })
        
        context.putGlobal(symbol: Builtins.intp.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 2 else {return .snull}
            
            switch parameters[1].eval(with: context,  level: level+1)!.1! {
            case .Atom(let v):
                
                switch v{
                case .int(_):
                    return.strue
                default:
                    return .snull
                }
                
             
            default:
                return .snull
            }
        })
        
        context.putGlobal(symbol: Builtins.doublep.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 2 else {return .snull}
            
            switch parameters[1].eval(with: context,  level: level+1)!.1! {
            case .Atom(let v):
                
                switch v{
                case .double(_):
                    return.strue
                default:
                    return .snull
                }
                
             
            default:
                return .snull
            }
        })

        context.putGlobal(symbol: Builtins.stringp.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 2 else {return .snull}
            
            switch parameters[1].eval(with: context,  level: level+1)!.1! {
            case .Atom(let v):
                
                switch v{
                case .string(_):
                    return.strue
                default:
                    return .snull
                }
                
             
            default:
                return .snull
            }
        })
        
        context.putGlobal(symbol: Builtins.booleanp.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 2 else {return .snull}
            
            switch parameters[1].eval(with: context,  level: level+1)!.1! {
            case .Atom(let v):
                
                switch v{
                case .boolean(_):
                    return.strue
                default:
                    return .snull
                }
                
             
            default:
                return .snull
            }
        })
        //MARK: Logic
        
        context.putGlobal(symbol: Builtins.not.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 2 else {return .snull}
            
            
            return .Atom(.boolean(parameters[1].isFalse()))
        })
        
        context.putGlobal(symbol: Builtins.and.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count >= 3 else {return .snull}
            
            guard case let .Atom(v1) = parameters[1] else {return .snull}
            guard case let .Atom(v2) = parameters[2] else {return .snull}
            
            return .Atom(.boolean(v1.booleanValue && v2.booleanValue))
        })
 
        context.putGlobal(symbol: Builtins.or.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 3 else {return .snull}
            guard case let .Atom(v1) = parameters[1] else {return .snull}
            guard case let .Atom(v2) = parameters[2] else {return .snull}
            return .Atom(.boolean(v1.booleanValue || v2.booleanValue))
        })

        context.putGlobal(symbol: Builtins.greater.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 3 else {return .snull}
            guard case let .Atom(v1) = parameters[1] else {return .snull}
            guard case let .Atom(v2) = parameters[2] else {return .snull}
            
            
            switch (v1, v2){
                
            case (.string(let s1), .string(let s2)):
                return .Atom(.boolean(s1 > s2))
                
            default:
                return .Atom(.boolean(v1.doubleValue > v2.doubleValue))
            }
        })

        context.putGlobal(symbol: Builtins.lesser.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 3 else {return .snull}
            guard case let .Atom(v1) = parameters[1] else {return .snull}
            guard case let .Atom(v2) = parameters[2] else {return .snull}
            
            
            switch (v1, v2){
                
            case (.string(let s1), .string(let s2)):
                return .Atom(.boolean(s1 < s2))
                
            default:
                return .Atom(.boolean(v1.doubleValue < v2.doubleValue))
            }
        })
        
        context.putGlobal(symbol: Builtins.greaterOrEqual.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 3 else {return .snull}
            guard case let .Atom(v1) = parameters[1] else {return .snull}
            guard case let .Atom(v2) = parameters[2] else {return .snull}
            
            
            switch (v1, v2){
                
            case (.string(let s1), .string(let s2)):
                return .Atom(.boolean(s1 >= s2))
                
            default:
                return .Atom(.boolean(v1.doubleValue >= v2.doubleValue))
            }
        })

        context.putGlobal(symbol: Builtins.lesserOrEqual.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 3 else {return .snull}
            guard case let .Atom(v1) = parameters[1] else {return .snull}
            guard case let .Atom(v2) = parameters[2] else {return .snull}
            
            
            switch (v1, v2){
                
            case (.string(let s1), .string(let s2)):
                return .Atom(.boolean(s1 <= s2))
                
            default:
                return .Atom(.boolean(v1.doubleValue <= v2.doubleValue))
            }
        })

        
        
        
        //MARK: Math
        
        context.putGlobal(symbol: Builtins.add.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count >= 2 else {return .snull}
            
            var acumd = 0.0
            var acumi = 0
            var isInt = true
            
            for p in parameters.dropFirst() { // add will maintain type if possible. If not will upgrade (1.0 es Double 1 Int (+ 1.0 1) es Double
                guard case let .Atom(sp1) = p else {continue}
                
                switch (sp1) {
                case .double(let d):
                    if isInt {
                        isInt = false
                        acumd = Double(acumi)
                        
                    }
                    acumd += d
                    
                case .int(let i):
                    if isInt {
                        acumi += i
                    }else{
                        acumd += Double(i)
                    }
                    
                case .string(let s):
                    if isInt {
                        if let i = Int(s){
                            acumi += i
                        }else if let d = Double(s){
                            acumd = Double(acumi)
                            acumd += d
                            isInt = false
                        }
                        
                    }else{
                        
                        if let d = Double(s){
                            acumd += d
                        }
                    }
                    
                case .boolean(_):
                    if isInt {
                        acumi += sp1.intValue
                     }else{
                        acumd += sp1.doubleValue
                    }
                    
                default:
                    return .snull
                }
                
                
                
            }
            if isInt {
                return .Atom(.int(acumi))
            }else{
                return .Atom(.double(acumd))
            }
        })
        
        context.putGlobal(symbol: Builtins.multiply.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count >= 2 else {return .snull}
            
            var acumd = 1.0
            var acumi = 1
            var isInt = true
            
            for p in parameters.dropFirst() { // add will maintain type if possible. If not will upgrade (1.0 es Double 1 Int (+ 1.0 1) es Double
                guard case let .Atom(sp1) = p else {continue}
                
                switch (sp1) {
                case .double(let d):
                    if isInt {
                        isInt = false
                        acumd = Double(acumi)
                        
                    }
                    acumd *= d
                    
                case .int(let i):
                    if isInt {
                        acumi *= i
                    }else{
                        acumd *= Double(i)
                    }
                    
                case .string(let s):
                    if isInt {
                        if let i = Int(s){
                            acumi *= i
                        }else if let d = Double(s){
                            acumd = Double(acumi)
                            acumd *= d
                            isInt = false
                        }
                        
                    }else{
                        if let d = Double(s){
                            acumd *= d
                        }
                    }
                    
                case .boolean(_):
                    if isInt {
                        acumi *= sp1.intValue
                    }else{
                        acumd *= sp1.doubleValue
                    }
                    
                default:
                    return .snull
                }
                
            }
            if isInt {
                return .Atom(.int(acumi))
            }else{
                return .Atom(.double(acumd))
            }
        })
        
        context.putGlobal(symbol: Builtins.subtract.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 3 else {return .snull}
            
            
            guard case let .Atom(sp1) = parameters[1] else {return .snull}
            guard case let .Atom(sp2) = parameters[2]  else {return .snull}
            
            switch (sp1, sp2){
            case  (.int(let v1), .int(let v2)):
                return .Atom(.int(v1 - v2))
                
            case  (.double(let v1), .double(let v2)):
                return .Atom(.double(v1 - v2))
                
            case  (.int(let v1), .double(let v2)):
                return .Atom(.double(Double(v1) - v2))
                
            case  (.double(let v1), .int(let v2)):
                return .Atom(.double(v1 - Double(v2)))
                
            default:
                return .snull
                
            }
            
        })
        
        context.putGlobal(symbol: Builtins.divide.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 3 else {return .snull}
            
            
            guard case let .Atom(sp1) = parameters[1] else {return .snull}
            guard case let .Atom(sp2) = parameters[2]  else {return .snull}
            
            switch (sp1, sp2){
            case  (.int(let v1), .int(let v2)):
                return .Atom(.int(v1 / v2))
                
            case  (.double(let v1), .double(let v2)):
                return .Atom(.double(v1 / v2))
                
            case  (.int(let v1), .double(let v2)):
                return .Atom(.double(Double(v1) / v2))
                
            case  (.double(let v1), .int(let v2)):
                return .Atom(.double(v1 / Double(v2)))
                
            default:
                return .snull
                
            }
        })
        
        context.putGlobal(symbol: Builtins.mod.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 3 else {return .snull}
            
            
            guard case let .Atom(sp1) = parameters[1] else {return .snull}
            guard case let .Atom(sp2) = parameters[2]  else {return .snull}
            
            switch (sp1, sp2){
            case  (.int(let v1), .int(let v2)):
                return .Atom(.int(v1 % v2))
                
            case  (.double(let v1), .double(let v2)):
                return .Atom(.double(v1.truncatingRemainder(dividingBy:v2)))
                
            case  (.int(let v1), .double(let v2)):
                return .Atom(.double(Double(v1).truncatingRemainder(dividingBy:v2)))
                
            case  (.double(let v1), .int(let v2)):
                return .Atom(.double(v1.truncatingRemainder(dividingBy: Double(v2))))
                
            default:
                return .snull
                
            }
        })
        
        context.putGlobal(symbol: Builtins.sin.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 2 else {return .snull}
            guard case let .Atom(sp1) = parameters[1] else {return .snull}

            return .Atom(.double(sin(sp1.doubleValue)))

        })
        
        context.putGlobal(symbol: Builtins.cos.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 2 else {return .snull}
            guard case let .Atom(sp1) = parameters[1] else {return .snull}
             
            return .Atom(.double(cos(sp1.doubleValue)))
         
        })
        context.putGlobal(symbol: Builtins.tan.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 2 else {return .snull}
            guard case let .Atom(sp1) = parameters[1] else {return .snull}
             
            return .Atom(.double(tan(sp1.doubleValue)))
         
        })

        context.putGlobal(symbol: Builtins.asin.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 2 else {return .snull}
            guard case let .Atom(sp1) = parameters[1] else {return .snull}
             
            return .Atom(.double(asin(sp1.doubleValue)))
        })
        
        context.putGlobal(symbol: Builtins.acos.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 2 else {return .snull}
            guard case let .Atom(sp1) = parameters[1] else {return .snull}
             
            return .Atom(.double(acos(sp1.doubleValue)))
        })
        context.putGlobal(symbol: Builtins.atan.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 2 else {return .snull}
            guard case let .Atom(sp1) = parameters[1] else {return .snull}
             
            return .Atom(.double(atan(sp1.doubleValue)))
        })
        
        context.putGlobal(symbol: Builtins.atan2.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 3 else {return .snull}
            guard case let .Atom(sp1) = parameters[1] else {return .snull}
            guard case let .Atom(sp2) = parameters[2] else {return .snull}
 
            return .Atom(.double(atan2(sp1.doubleValue, sp2.doubleValue)))
        })
        
        context.putGlobal(symbol: Builtins.sqr.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 2 else {return .snull}
            guard case let .Atom(sp1) = parameters[1] else {return .snull}
            
            switch sp1 {
            case .int(let v):
                return .Atom(.int(v * v))
                
            case .double(let v):
                return .Atom(.double(v * v))
                
            default:
                return .snull
            }
            

        })
        
        context.putGlobal(symbol: Builtins.abs.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 2 else {return .snull}
            guard case let .Atom(sp1) = parameters[1] else {return .snull}
            
            switch sp1 {
            case .double(let v1):
                return .Atom(.double(fabs(v1)))
                
            case .int(let v1):
                return .Atom(.int(abs(v1)))
                
            default:
                return .Atom(.double(fabs(sp1.doubleValue)))
            }
         })
        
        context.putGlobal(symbol: Builtins.sqrt.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 2 else {return .snull}
            guard case let .Atom(sp1) = parameters[1] else {return .snull}
            
            return  .Atom(.double(sqrt(sp1.doubleValue)))
            
         })
        
        context.putGlobal(symbol: Builtins.exp.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 2 else {return .snull}
            guard case let .Atom(sp1) = parameters[1] else {return .snull}
            
            return  .Atom(.double(exp(sp1.doubleValue)))
            
         })
        
        context.putGlobal(symbol: Builtins.ln.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 2 else {return .snull}
            guard case let .Atom(sp1) = parameters[1] else {return .snull}
            
            return  .Atom(.double(log(sp1.doubleValue)))
            
         })
        
        context.putGlobal(symbol: Builtins.pwr.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 3 else {return .snull}
            guard case let .Atom(sp1) = parameters[1] else {return .snull}
            guard case let .Atom(sp2) = parameters[2] else {return .snull}
            
            if case .int(_) = sp1, case .int(_) = sp2 {
                return  .Atom(.int(Int(pow(sp1.doubleValue, sp2.doubleValue))))
            }else{
                return  .Atom(.double(pow(sp1.doubleValue, sp2.doubleValue)))
            }
            
         })
        
        context.putGlobal(symbol: Builtins.floor.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 2 else {return .snull}
            guard case let .Atom(sp1) = parameters[1] else {return .snull}
            
            return  .Atom(.int(Int(floor(sp1.doubleValue))))
            
         })
        // MARK: Vectors
            
        
        context.putGlobal(symbol: Builtins.vadd.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 3 else {return .snull}
            guard case .List(_) = parameters[1] else {return .snull}
            guard case .List(_) = parameters[2] else {return .snull}
            
            return parameters[1].vadd(parameters[2])
          })
        
        context.putGlobal(symbol: Builtins.vsubtract.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 3 else {return .snull}
            guard case .List(_) = parameters[1] else {return .snull}
            guard case .List(_) = parameters[2] else {return .snull}
            
            return parameters[1].vsubtract(parameters[2])
          })
        
        
        context.putGlobal(symbol: Builtins.vdot.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 3 else {return .snull}
            guard case .List(_) = parameters[1] else {return .snull}
            guard case .List(_) = parameters[2] else {return .snull}
            
            return parameters[1].vdot(parameters[2])
          })
        context.putGlobal(symbol: Builtins.vcross.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 3 else {return .snull}
            guard case .List(_) = parameters[1] else {return .snull}
            guard case .List(_) = parameters[2] else {return .snull}
            
            return parameters[1].vcross(parameters[2])
          })
        
        context.putGlobal(symbol: Builtins.vmultiply.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 3 else {return .snull}
            guard case .List(_) = parameters[1] else {return .snull}
            guard case let .Atom(sp2) = parameters[2] else {return .snull}
            
            return parameters[1].vmultiply(sp2.doubleValue)
          })
        // MARK: Direct Access List
        
        context.putGlobal(symbol: Builtins.count.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 2 else {return .snull}
            guard case let .List(sp1) = parameters[1] else {return .snull}
            
            return .Atom(.int(sp1.count))
            
         })
        
        context.putGlobal(symbol: Builtins.item.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 3 else {return .snull}
            guard case let .Atom(sp1) = parameters[1] else {return .snull}
            guard case let .List(sp2) = parameters[2] else {return .snull}
            
            let i = sp1.intValue
            guard i >= 0 && i < sp2.count else { return .snull}
            return sp2[i]
             
         })
        
        // item, new value, list
        context.putGlobal(symbol: Builtins.replaceItem.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 4 else {return .snull}
            guard case let .Atom(sp1) = parameters[1] else {return .snull}
            guard case let .List(sp3) = parameters[3] else {return .snull}
            
            var llista = sp3
            let i = sp1.intValue
            if i < sp3.count {
                llista[i] = parameters[2]
            }
            return .List(llista)
         })
        
        // MARK: Objects
        // (get dict key)
        
        context.putGlobal(symbol: Builtins.object.rawValue, specialForm: true, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 2 else {return .snull}
            guard case let .List(sp1) = parameters[1] else {return .snull}
            
            var d = Dictionary<String, SExpr>()
            
            sp1.forEach { sexpr in
                switch sexpr{
                case .List(let items):
                    d[items[0].stringValue] = items[1].eval(with: context, level: level+1)?.1 ?? .snull
                
                default:
                    break
                }
            }
            let o = LispObject(data: d)
            Lisp.shared.addObject(o)
            return .Atom(.object(o.id))
            
            
         })
 
        
        context.putGlobal(symbol: Builtins.fget.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 3 else {return .snull}
            guard case let .Atom(sp1) = parameters[1] else {return .snull}
            guard case let .Atom(sp2) = parameters[2] else {return .snull}
            
            guard case let .object(uuid) = sp1 , let obj = Lisp.shared.getObject(uuid) else {return .snull}
            
            let field = sp2.stringValue
            return obj.valueFor(field) ?? .snull
            
            
         })
        
        context.putGlobal(symbol: Builtins.fset.rawValue, specialForm: false, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 4 else {return .snull}
            guard case let .Atom(sp1) = parameters[1] else {return .snull}
            guard case let .Atom(sp2) = parameters[2] else {return .snull}
            
            guard case let .object(uuid) = sp1 else {return .snull}
            if let obj = Lisp.shared.getObject(uuid){
                 let field = sp2.stringValue
                 let value  = parameters[3].eval(with: context, level: level+1)?.1 ?? .snull
                obj.setValueFor(field, value: value)
                return parameters[3]
            }else{
                return .snull
            }
            
            
         })
        
        // MARK: Strings
        
        context.putGlobal(symbol: Builtins.split.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 3 else {return .snull}
            guard case let .Atom(sp1) = parameters[1] else {return .snull}
            guard case let .List(sp3) = parameters[2] else {return .snull}
            
            
            // sp3 must have unicode characters
            var splitSet : CharacterSet = []
            
            sp3.forEach { item in
                switch item {
                case .Atom(let v):
                    if let x = UnicodeScalar(v.intValue){
                        splitSet.insert(x)
                    }
                    
                default:
                    break
                }
            }
            
            let llista = sp1.stringValue.components(separatedBy: splitSet)
            let atoms = llista.map({ s in
                    SExpr.Atom(.string(s))
                          })
            return .List(atoms)
            
         })
        
        context.putGlobal(symbol: Builtins.explode.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 2 else {return .snull}
            guard case let .Atom(sp1) = parameters[1] else {return .snull}
            
            let v = sp1.stringValue
            
            
            let atomArray = v.unicodeScalars.map { c in
                SExpr.Atom(.int(Int(c.value)))
            }
            
            return  .List(atomArray)
            
         })
        
        // parameter is a list of Unicode scalars
        context.putGlobal(symbol: Builtins.implode.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 2 else {return .snull}
            guard case let .List(sp1) = parameters[1] else {return .snull}
            
            
            let values : [Character] = sp1.map { sexpr in
                switch sexpr {
                case .Atom(let v):
                    Character(UnicodeScalar(UInt32(v.intValue)) ?? UnicodeScalar(" "))
                    
                default:
                    Character(" ")
                }
            }
            
            let s = String(values)
            
            return  .Atom(.string(s))
            
         })
        
        // Concat es equivalent a un flatten i despres concatena els stringValue en un sol string
        
        context.putGlobal(symbol: Builtins.concat.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count >= 2 else {return .snull}
              
            let s : String = parameters.dropFirst().reduce("") { partialResult, sexpr in
                partialResult + sexpr.stringValue
            }
            
            return  .Atom(.string(s))
            
         })
        
        
        context.putGlobal(symbol: Builtins.hasprefix.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 3 else {return .snull}
              
            guard case let .Atom(str) = parameters[1] else {return .snull}
            guard case let .Atom(pat) = parameters[2] else {return .snull}
            
            return .Atom(.boolean(str.stringValue.hasPrefix(pat.stringValue)))
            
         })
        
        context.putGlobal(symbol: Builtins.hassuffix.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 3 else {return .snull}
              
            guard case let .Atom(str) = parameters[1] else {return .snull}
            guard case let .Atom(pat) = parameters[2] else {return .snull}
            
            return .Atom(.boolean(str.stringValue.hasSuffix(pat.stringValue)))
            
         })

        context.putGlobal(symbol: Builtins.contains.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 3 else {return .snull}
              
            guard case let .Atom(str) = parameters[1] else {return .snull}
            guard case let .Atom(pat) = parameters[2] else {return .snull}
            
            do{
                let regex = try Regex(pat.stringValue)
                
                return .Atom(.boolean(str.stringValue.contains(regex)))
                
            }catch{
                return .snull
            }
            
         })
        
        context.putGlobal(symbol: Builtins.matches.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 3 else {return .snull}
              
            guard case let .Atom(str) = parameters[1] else {return .snull}
            guard case let .Atom(pat) = parameters[2] else {return .snull}
            
            do{
                let regex = try Regex(pat.stringValue)
                let s = str.stringValue
                let matches = s.matches(of: regex)
                
                let l = matches.map { match in
                        SExpr.List(Array(stride(from: 0, through: match.count-1, by: 1)).map { i in
                            SExpr.List([
                                SExpr.Atom(.string(match[i].name ?? "")),
                                SExpr.Atom(.string(String(match[i].value as! Substring)))]
                        )
                    })
                        
                }
                
                return SExpr.List(l)
                
            }catch{
                return .snull
            }
            
         })

        // MARK: Geometry
        
        context.putGlobal(symbol: Builtins.p2r.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 2 else {return .snull}
            guard case let .List(sp1) = parameters[1] else {return .snull}
            
            guard case let .Atom(p0) = sp1[0] else {return .snull}
            guard case let .Atom(p1) = sp1[1] else {return .snull}
            
            
            if sp1.count == 3{
                guard case let .Atom(p2) = sp1[2] else {return .snull}
                let r = p0.doubleValue
                let theta = p1.doubleValue
                let phi = p2.doubleValue
                return .List([.Atom(.double(r * sin(phi) * cos(theta))),
                                  .Atom(.double(r * sin(phi) * sin(theta))),
                                  .Atom(.double(r * cos(phi)))
                    ])
                
            }else if sp1.count == 2{
                let r = p0.doubleValue
                let theta = p1.doubleValue
                return .List([.Atom(.double(r * cos(theta))),
                                  .Atom(.double(r * sin(theta)))
                    ])
                
                
            }
            else{
                return .snull
            }
        })
        
        context.putGlobal(symbol: Builtins.r2p.rawValue, value: { params, context , level in
            guard case let .List(parameters) = params, parameters.count == 2 else {return .snull}
            guard case let .List(sp1) = parameters[1] else {return .snull}
            guard sp1.count >= 2 && sp1.count <= 3 else {return .snull}
            guard case let .Atom(p0) = sp1[0] else {return .snull}
            guard case let .Atom(p1) = sp1[1] else {return .snull}
            
            if sp1.count == 3{
                
                guard case let .Atom(p2) = sp1[2] else {return .snull}
                
                let x = p0.doubleValue
                let y = p1.doubleValue
                let z = p2.doubleValue
                    
                    return .List([.Atom(.double(sqrt(x * x + y * y + z * z))),
                                  .Atom(.double(atan2(y, x))),
                                  .Atom(.double(atan2(sqrt(x * x + y * y), z)))
                    ])
                
            }
            
            else if sp1.count == 2{
                
                let x = p0.doubleValue
                let y = p1.doubleValue
                return .List([.Atom(.double(sqrt(x * x + y * y ))),
                                  .Atom(.double(atan2(y, x)))
                    ])
                
            }
            else{
                return .snull
            }
        })
        
        //MARK: File Manager
 
        context.putGlobal(symbol: Builtins.home.rawValue, value: { params, context, level in
            let path = FileManager.default.homeDirectoryForCurrentUser.path
            return .Atom(.string(path))
        })
        
        context.putGlobal(symbol: Builtins.pwd.rawValue, value: { params, context, level in
            let path = FileManager.default.currentDirectoryPath
            return .Atom(.string(path))
        })
        
        context.putGlobal(symbol: Builtins.cd.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 2 else {return .snull}
            guard case let .Atom(sp1) = parameters[1] else {return .snull}
            
            let path = sp1.stringValue
            
            FileManager.default.changeCurrentDirectoryPath(path)
            return .Atom(.string( FileManager.default.currentDirectoryPath))
        })
        
        context.putGlobal(symbol: Builtins.ls.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params else {return .snull}
            
            var path = FileManager.default.currentDirectoryPath
            
            if parameters.count > 1 { // No parameters, path = currentDirectory
                guard case let .Atom(sp1) = parameters[1] else {return .snull}
                let name = sp1.stringValue
                if name.hasPrefix("/"){
                    path = name
                }else{
                    path = path + "/" + sp1.stringValue
                }
            }
            
            do{
                let files = try FileManager.default.contentsOfDirectory(atPath: path).map { f in
                    SExpr.Atom(.string(f))
                }
                return .List(files)
            }catch{
                return .snull
            }
        })
        
        context.putGlobal(symbol: Builtins.read.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 2 else {return .snull}
            guard case let .Atom(sp1) = parameters[1] else {return .snull}
            
            let path = sp1.stringValue
            
            do {
                let url = URL(fileURLWithPath: path)
                let data = try Data(contentsOf: url)
                
                if let str = String(data: data, encoding: .utf8){
                    return .Atom(.string(str))
                }else if let img = NSImage(data: data){
                    return .Atom(.image(img))
                 }else{
                    return .Atom(.binary(data))
                }
                
            } catch {
                return .snull
            }
        })
        
        
        context.putGlobal(symbol: Builtins.write.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 3 else {return .snull}
            guard case let .Atom(sp1) = parameters[1] else {return .snull}
            guard case let .Atom(sp2) = parameters[2] else {return .snull}
            let path = sp2.stringValue
            
            do {
                switch sp1 {
                case .binary(let data):
                    if data != nil {
                        try data!.write(to: URL(fileURLWithPath: path))
                    }
                    return .strue
                    
                case .image(let img):
                    if let img = img {
                        if let imageRep = NSBitmapImageRep(data: img.tiffRepresentation!){
                            
                            let url = URL(fileURLWithPath: path)
                            let ext = url.pathExtension.lowercased()
                            
                            var type : NSBitmapImageRep.FileType
                            
                            switch ext {
                            case "png":
                                type = .png
                                
                            case "jpg", "jpeg":
                                type = .jpeg
                                
                            case "gif":
                                type = .gif
                            default:
                                type = .tiff
                            }
                            
                            
                            
                            let pngData = imageRep.representation(using: type, properties: [:])
                            guard (try? pngData?.write(to: url)) != nil else {return .snull}
                            return .strue
                        }
                    }
                    return .snull
                default:
                    try sp1.stringValue.write(toFile: path, atomically: true, encoding: .utf8)
                    return .strue
                }
               
            } catch {
                return .snull
            }
        })
        
    //MARK: http
        context.putGlobal(symbol: Builtins.get.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 2 else {return .snull}
            guard case let .Atom(sp1) = parameters[1] else {return .snull}
            
            guard let url = URL(string: sp1.stringValue) else {return .snull}
            
            do {
                let data = try Data(contentsOf: url)
                if let str = String(data: data, encoding: .utf8){
                    return .Atom(.string(str))
                }else if let img = NSImage(data: data){
                    
                    return .Atom(.image(img))
                 }else{
                    return .Atom(.binary(data))
                }
                
            } catch {
                return .snull
            }
        })

        context.putGlobal(symbol: Builtins.urlscheme.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 2 else {return .snull}
            guard case let .Atom(sp1) = parameters[1] else {return .snull}
            
            guard let url = URL(string: sp1.stringValue) else {return .snull}
            
            if let scheme = url.scheme {
                
                return .Atom(.string(scheme))
            }else{
                return .snull
            }
        })
        
        context.putGlobal(symbol: Builtins.urlpath.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 2 else {return .snull}
            guard case let .Atom(sp1) = parameters[1] else {return .snull}
            
            guard let url = URL(string: sp1.stringValue) else {return .snull}
            
            let path = url.path()
            return .Atom(.string(path))
            
        })
        context.putGlobal(symbol: Builtins.urlextension.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 2 else {return .snull}
            guard case let .Atom(sp1) = parameters[1] else {return .snull}
            
            guard let url = URL(string: sp1.stringValue) else {return .snull}
            
            let ext = url.pathExtension
            return .Atom(.string(ext))
        })
        context.putGlobal(symbol: Builtins.urlhost.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 2 else {return .snull}
            guard case let .Atom(sp1) = parameters[1] else {return .snull}
            
            guard let url = URL(string: sp1.stringValue) else {return .snull}
            
            if let host = url.host() {
                return .Atom(.string(host))
            }else{
                return .snull
            }
        })
        
        context.putGlobal(symbol: Builtins.urlport.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count == 2 else {return .snull}
            guard case let .Atom(sp1) = parameters[1] else {return .snull}
            
            guard let url = URL(string: sp1.stringValue) else {return .snull}
            
            if let port = url.port {
                return .Atom(.int(port))
            }else{
                return .snull
            }
        })
        
        //MARK: Processes
        
        context.putGlobal(symbol: Builtins.runprocess.rawValue, value: { params, context, level in
            guard case let .List(parameters) = params, parameters.count >= 2 else {return .snull}
            guard case let .Atom(sp1) = parameters[1] else {return .snull}
            
            let task = Process()
            task.executableURL = URL(fileURLWithPath: sp1.stringValue)
            
            
            
            let params = Array( Array(arrayLiteral: parameters.dropFirst(2)).joined())
            task.arguments = []
            
            for p in params {
                switch p {
                case .Atom(let v):
                    task.arguments?.append(v.stringValue)
                    
                case .List(let l):
                    for v in l {
                        task.arguments?.append(v.stringValue)
                    }
                    
                }
            }

            do{
                try task.run()
                return .strue
            }catch{
                return .snull
            }
           
        })
        
        //MARK : Auxiliar
        
        context.putGlobal(symbol: Builtins.printenv.rawValue, value: { params, context, level in
            
            // Get context level depth
            enum tipus {
                case all
                case vars
                case functions
                case objects
            }
            guard case let .List(parameters) = params else {return .snull}
            var selector = tipus.all
            if parameters.count == 2 {
                guard case let .Atom(value) = parameters[1] else {return .snull}
                if value == "v" {
                    selector = .vars
                } else if value == "f" {
                    selector = .functions
                }else if value == "o" {
                    selector = .objects
                }
                else {return .snull}
            }
            
            var c = context
            
            while c != nil {
                fputs ("Level \(c?.level ?? -1)\n", stderr)
                
                
                if (selector == .all || selector == .functions){
                    var s : String = ""
                    for k in c!.keys {
                        if c!.lookupFunction(symbol: k) != nil{
                            s = s + (s.isEmpty ? "" : ", ") + k
                        }
                    }
                    fputs("    Functions: \(s)\n", stderr)
                }
                if (selector == .all || selector == .vars) {
                    fputs("    Variables:\n", stderr)
                    for k in c!.keys {
                        let (_, v) = c!.lookup(k)!
                        if case let .Atom(a) = v {
                            if  case AtomValue.function = a {
                                
                            }else{
                                fputs("        \(k) => \(v.stringValue)\n", stderr)
                            }
                            
                        }else {
                            fputs("        \(k) => \(v.stringValue)\n", stderr)
                        }
                    }
                }
                
                c = c!.previousContext
                
            }
            if (selector == .all || selector == .objects) {
                fputs("    Objects:\n", stderr)
                
                for uuid in Lisp.shared.objectUUIDs(){
                    fputs(Lisp.shared.getObject(uuid)?.description ?? "***", stderr)
                }
               
            }
            return .snull
        })
        
    }
    
    func createClasses(){
        func buildImageClassObject() -> SExpr {
            
            var dict : Dictionary<String, SExpr> = [:]
            
            dict["size"] = .Atom(.function(name: "size", specialForm: false, f: { params, ctx, levelx in
                
                if let img = ctx?.lookup("self.img")?.1{
                    guard  case .Atom(let at) = img, case AtomValue.image(let nsimage) = at else {return .snull}
                    
                    if let s = nsimage?.size{
                        if let wide = nsimage?.representations[0].pixelsWide,
                           let high = nsimage?.representations[0].pixelsHigh{
                            return .List([ .List([.Atom(.double(s.width)), .Atom(.double(s.height))]),
                                .List([.Atom(.int(wide)), .Atom(.int(high))])
                                ]
                            )
                        }
                     }
                }
                
                return .snull
            })
            )
            
            dict["new"] = .Atom(.function(name: "new", specialForm: false, f: { params, ctx, levelx in
                guard case let .List(parameters) = params else {return .snull}
                guard case let .Atom(name) = parameters[1] else {return .snull}
                
                let url = URL(fileURLWithPath: name.stringValue)
                if let img = NSImage(contentsOf: url) {
                    
                    let someDict : Dictionary<String, SExpr> = ["kind-of" : .Atom(.string("image_class")),
                                                                "img": .Atom(.image(img))]
                    
                    let someObj = LispObject(data: someDict)
                    self.addObject(someObj)
                    return .Atom(.object(someObj.id))
                }
                
                return .snull
            })
            )
            let obj = LispObject( data: dict)
            self.addObject(obj)
            obj.incRef()
            return .Atom(.object(obj.id))
        }
        
        
        
        
        context.putGlobal(name: "image_class", value: buildImageClassObject())  // simplePut is used becaus Lisp.shared is not initialized

    }
}
