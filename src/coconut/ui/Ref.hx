package coconut.ui;

#if macro
import haxe.macro.Context.*;
import haxe.macro.Type;
using haxe.macro.Tools;
#end

@:callable
abstract Ref<T>(T->Void) from T->Void to T->Void {
  
  #if macro
  static function unwrap(t:TypedExpr)
    return switch t.expr {
      case TMeta(_, t) | TParenthesis(t) | TCast(t, _): 
        unwrap(t);
      default: t;
    }

  static function getRef(t:Type)
    return switch t {
      case TAbstract(_.get() => { pack: [], name: 'Null'}, [t]): getRef(t);
      case TAbstract(_.get() => { pack: ['coconut', 'ui'], name: 'Ref'}, [t]): t;
      case TLazy(f): getRef(f());
      default: throw 'assert';
    }
  #end

  @:from static macro function ofExpr(e) {

    var expected = getRef(getExpectedType());

    var ct = expected.toComplexType(),
        te = unwrap(typeExpr(e));

    var setter = 
      switch te.expr {
        case TField(_, FAnon(f) | FInstance(_, _, f) | FStatic(_, f)):
          var f = f.get();
          #if haxe4
          if (f.isFinal)
            fatalError('cannot store Ref in final field $f', e.pos);
          #end
          switch f.meta.extract(':refSetter') {
            case []: null;
            case [{ params: [v] }]: v; 
            default: fatalError('invalid @:refSetter meta', f.pos);
          }
        default: null;
      }
    
    return
      switch follow(te.t) {
        case TFun([{ t: t }], r):
          if (unify(expected, t))
            e;
          else
            fatalError('${te.t.toString()} should be Ref<${expected.toString()}>', e.pos);
        case t:
          e = storeTypedExpr(te);
          if (unify(expected, t))
            if (setter == null)
              macro @:pos(e.pos) function (__v:$ct) $e = __v;
            else 
              setter;
          else
            fatalError('${te.t.toString()} should be Ref<${expected.toString()}>', e.pos);
      }
  }
}