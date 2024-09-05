# My Lisp

This is a very simple lisp like language useful as a command line or for integrating in applications


## Overview

main program is the command line. It reads and executes a init.lisp file in currentDirectory.
Parameters may be passed and each one is a file that will be read and executed.

Special (clear) in a line clears input buffer and (quit) quits!!!

### Atoms

Atoms may be String (usual), Int (Int 64 in MacOS), Double, Boolean, Binary or Objects

### Functions

-   quote
-   car
-   cdr
-   cons
-   reversed
-   equal(=)
-   atomp
-   intp
-   doublep
-   stringp
-   booleanp
-   cond
-   lambda
-   defun
-   specialform
-   list
-   eval
-   progn
-   setq (sets global variable)
-   set (sets local variable)
-   removeq
-   remove
-   run (reads and runs file)
-   map
-   reduce
-   compact (removes null elements from list)
-   print
-   println
-   printenv (all, with f parameter functions, with v parameter variables, with o objects)
-   Arithmetic (+. *. -, /), + and * may be applied to many parameters (+ 1 2 3 4)
-   mod, abs. sin, cos, tan. asin, acos, atan, atan2, sqr, sqrt, exp, ln, pwr, floor
-   p2r and r2p to change bwtween rectangular and polar
-   >, <, >=, <=
-   not, and, or
-   pwd, cd, ls are like commands but ls returns a list of files
-   home is the home directory
-   read returns a string from a file
-   write writes a string to a file
-   count counts items in a list
-   item gets item of a list (item 4 (1 2 3 4 5 6)) is 5
-   replaceItem replaces and item in a list (replaceItem i value list)

### Strings

-   explode converts string to list of unicode ints
-   implode converts list of unicode ints to string
-   concat concats all string values with previuous flatten (concat (1 2 (3 4) 5 6)) is 123456
-   split splits string. (split string (int)) (int) is alist of unicode chars
-   hasprefix
-   hassuffix
-   contains (pot fer servir una regular expression (contains string regex))
-   matches (matches string reg) Retorns an array where each item is a match and if there are captures the captures
        for example ((match.1 capture1.1 capture1.2 ...) (match.2 capture.1.1 capture.2.2 ...))
        where match.1 is the total stricg matched, and captures are the () captured. If they have name (?<name>) they are labelled

### Vectors 

vectors should have same length
vcross only in 3d vectors

-   vadd
-   vsubtract
-   vdot
-   vcross
-   vmultiply (vmultiply vector scalar)

### Lisp defined functions internally

-   (if test stm1 stm2)
-   (map f list) - works with lambda, f has one parameter and f is applied to items in lñist
-   (reduce f init list) - Finction 2 parameters, init and item
-   (flatten list)
-   (compact list) removes null items
-   (defun r2d (x) (* (/ x Pi) 180))    radians to degrees
-   (defun d2r (x) (* (/ x 180) Pi))    degrees to radians

### Constants definitions

-   (setq blank \" \")
-   (setq Pi 3.141592)
-   (setq Pi2 (/ 3.141592 2))
-   (setq Pi4 (/ 3.141592 4))
-   (setq e 2.718281828459045)
-   (setq null (quote ()))
-   (setq trace (quote ()))
-   (setq newlines (list 10 13 133 8232 8233 ))

### Files, environment and URL'2

-   home    gives homeDirectory
-   pwd  current Directory
-   (cd path)   change current directory
-   ls or (ls path) list files in directory
-   (read path) returns contents of file. As String or Binary
-   (wite value path) Writes data either string or binary
-   (get url) Same as read but with an url
-   (urlscheme url) gives the scheme (http, https...)
-   (urlpath url) gives the path
-   (urlextension url) gives path extension
-   (urlhost url) returns the host
-   (urlport url) returns the port
-   (runprocess program p1 p2 ....) Executes process as task

### Wraps and others

-   lsview  Same as ls but filters non visible
-   (openapp app (files)) Opens app (may be just name as Preview) and passes files as parameters
-   (openfiles (files)) Opens the files with default app

### Matrices (They are different as other vectors)

They are implemented as lists of lists

Even scalars (dimension 1, 1) are a ((value))

Defines covariant (v * m) and contravariant (m * v) vectors. Covariant have one row, contravariant one column.

rows of a matrix may be accessed as a list directly
columns as the transposed

-   (row i m) returns row i of matrix m
-   (column i m) returns column i of matrix m
-   (range m) returns (rows columns)
-   (covariant (list)) creates a covariant vector
-   (contravariant (list)) creates a contravariant vector
-   (madd m1 m2) adds 2 matrices of equal ranges
-   (msubtract m1 m2) subtracts m2 from m1
-   (mmultiply number m) multiplies all elements of m by number
-   (mproduct m1 m2) matrix product of m1 and m2
-   (iscovariant v) true if is covariant
-   (iscontravariant v) true if contravariant
-   (transposed m) returns transposed matrix

### Objects

Objects are stored in its own space (heap) which is a dictionary indexed by a UUID
Each Object is a class with an id (UUID), a reference count (references) and a dictionary,
The dictionary is <String, SExpr> where the index are the fields
They are a type of Atom created by the **object** keyword that store the UUID
Every time a variable is assigned to an atom type object, or an object field is assigned to an object
the corresponding object reference count is incremented.
Everytime the value of a field that poitns to an object is changed old object references are decreased
When an variable which points to an object is eliminated either by removing a context or with the removeq operator the object references are decremented.
When references equal 0 the object is purged from the heap.

Dot notation is used to access field
Field kind-of points to something similar to a class. Values may be inherited from the kind-of
Field name is not mandatory but convenient to inspect the objects
Field values may be a lambda. When lambda is executed a special atom **self** that points to the actual object

For example supose we define:

    (setq thing (object ((name Thing) (pr (lambda () (println self.name)))    )) )
    (setq livingThing (object ((name livingThing) (kind-of thing) (living true))))
    (setq otherThing (object ((name otherThing)(kind-of thing) (living false))))
    (setq animal (object ((kind-of livingThing) (name animal) (hasCellularWall false))))
    (setq vegetal (object ((kind-of livingThing) (name vegetal) (hasCellularWall true))))
    (setq mineral (object ((kind-of otherThing) (name mineral))))
    (setq mamifer (object ((kind-of animal) (name mamifer)(hasFur true) (producesMilk true))))
    (setq reptile (object ((kind-of animal) (name reptile)(laysEggs true))))
    (setq human (object ((kind-of mamifer) (name human)(walksOnTwoLegs true) (hasBigBrain true) (numberOfChromosomes 48))))
    (setq man (object ((kind-of human)(name man) (hasYChromosome true))))
    (setq woman (object ((kind-of human) (name woman)(hasYChromosome false))))

    (setq alice (object ((kind-of woman) (name Alice) )))
    (setq caroline (object ((kind-of woman) (name Caroline) )))
    (setq bob (object ((kind-of man) (name Bob) (partner alice) )))

Then
    (println alice.name)
    
prints "Alice"

    (println bob.partner.name)
    
also prints "Alice"

    (bob.pr)
    
prints "Bob" as pr is defined in thing but uses self.name and is executed from Bob

Inherited fields work :

    (println bob.hasCellularWall)
    
is false because bob is not a Vegetal but 

    (println bob.hasFur)
    
is true because bob is a mamifer

Primitives working on objects are 

- (object name ((field value)(field value) ...))
- (fset object field value)
- (fget object field value)

Difference from 

    (println bob.partner)
    
and 
    (println (fget bob partner))
    
is that bob.partner evaluates partner so it prints

    (println bob.partner)
    "    name: Alice
    kind-of: woman" 

but fget no:

    (println (fget bob partner))
    alice 
    
Also objects are represented as variables in a context. So if we store it with setq they have long life
but if we store it with set then it will dissapear when canging the context.

Example:
    
    (progn
        (set tim (object ((name Tim))))
        (println tim.name)
    )
    Tim 
    (println tim)
    tim 


But 

    (progn
        (setq tim (object ((name Tim))))
        (println tim.name)
    )
    Tim 

    (println tim)
    "    name: Tim" 

When doing references to an object from another object, the linked object is looked up from the context where the original one is located

So we may have

    (setq alice (object ((kind-of woman) (name Alice) )))
    (setq bob (object ((kind-of man) (name Bob) (partner alice) )))
    (progn 
        (set alice (object ((kind-of woman) (name Alicia) )))
        (println alice.name)
        (println bob.partner.name)
    )

will print
    Alicia
    Alice
    
Because first alice.name is looked up in progn context but bob.partner is looked up in bob's context

Also if we do:

   (progn 
    (set alice (object ((kind-of woman) (name Alicia) )))
    (set bob (object ((kind-of man) (name Boby) (partner alice) )))
    (println bob.name)
    (println alice.name)
    (println bob.partner.name)
    (println alice.name)
)

We get  

    Boby 
    Alicia 
    Alicia 
    Alicia 

Because bob's context is now the progn context
