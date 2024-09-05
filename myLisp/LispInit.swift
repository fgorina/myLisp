//
//  LispInit.swift
//  myLisp
//
//  Created by Francisco Gorina Vanrell on 30/7/24.
//

import Foundation

var swFunctions : [String] = [
    
    "(setq blank \" \")",
    "(setq Pi 3.141592)",
    "(setq Pi2 (/ 3.141592 2))",
    "(setq Pi4 (/ 3.141592 4))",
    "(setq e 2.718281828459045)",
    "(defun r2d (x) (* (/ x Pi) 180))",
    "(defun d2r (x) (* (/ x 180) Pi))",
    "(setq null (quote ()))",
    "(setq trace (quote ()))",
    "(setq newlines (list 10 13 133 8232 8233 ))",
"""
(specialform if (test stm1 stm2)
    (cond
        ((eval test) (eval stm1))
        ((quote true) (eval stm2))
    )
)
""",

"""
(defun flatten (l)
    (cond
        ((= l null) ())
        ((atomp (car l)) (cons (car l) (flatten(cdr l))))
        ((quote true)  (list (flatten (car l)) (flatten (cdr l)) ))

    )
)
""",

"""
(defun land(l)
    (reduce and true l)
)
""",
"""
(defun lor(l)
    (reduce or false l)
)
"""
]
