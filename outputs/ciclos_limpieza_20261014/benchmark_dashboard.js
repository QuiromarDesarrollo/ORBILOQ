(function dartProgram(){function copyProperties(a,b){var t=Object.keys(a)
for(var s=0;s<t.length;s++){var r=t[s]
b[r]=a[r]}}function mixinPropertiesHard(a,b){var t=Object.keys(a)
for(var s=0;s<t.length;s++){var r=t[s]
if(!b.hasOwnProperty(r)){b[r]=a[r]}}}function mixinPropertiesEasy(a,b){Object.assign(b,a)}var z=function(){var t=function(){}
t.prototype={p:{}}
var s=new t()
if(!(Object.getPrototypeOf(s)&&Object.getPrototypeOf(s).p===t.prototype.p))return false
try{if(typeof navigator!="undefined"&&typeof navigator.userAgent=="string"&&navigator.userAgent.indexOf("Chrome/")>=0)return true
if(typeof version=="function"&&version.length==0){var r=version()
if(/^\d+\.\d+\.\d+\.\d+$/.test(r))return true}}catch(q){}return false}()
function inherit(a,b){a.prototype.constructor=a
a.prototype["$i"+a.name]=a
if(b!=null){if(z){Object.setPrototypeOf(a.prototype,b.prototype)
return}var t=Object.create(b.prototype)
copyProperties(a.prototype,t)
a.prototype=t}}function inheritMany(a,b){for(var t=0;t<b.length;t++){inherit(b[t],a)}}function mixinEasy(a,b){mixinPropertiesEasy(b.prototype,a.prototype)
a.prototype.constructor=a}function mixinHard(a,b){mixinPropertiesHard(b.prototype,a.prototype)
a.prototype.constructor=a}function lazy(a,b,c,d){var t=a
a[b]=t
a[c]=function(){if(a[b]===t){a[b]=d()}a[c]=function(){return this[b]}
return a[b]}}function lazyFinal(a,b,c,d){var t=a
a[b]=t
a[c]=function(){if(a[b]===t){var s=d()
if(a[b]!==t){A.eP(b)}a[b]=s}var r=a[b]
a[c]=function(){return r}
return r}}function makeConstList(a,b){if(b!=null)A.b(a,b)
a.$flags=7
return a}function convertToFastObject(a){function t(){}t.prototype=a
new t()
return a}function convertAllToFastObject(a){for(var t=0;t<a.length;++t){convertToFastObject(a[t])}}var y=0
function instanceTearOffGetter(a,b){var t=null
return a?function(c){if(t===null)t=A.cl(b)
return new t(c,this)}:function(){if(t===null)t=A.cl(b)
return new t(this,null)}}function staticTearOffGetter(a){var t=null
return function(){if(t===null)t=A.cl(a).prototype
return t}}var x=0
function tearOffParameters(a,b,c,d,e,f,g,h,i,j){if(typeof h=="number"){h+=x}return{co:a,iS:b,iI:c,rC:d,dV:e,cs:f,fs:g,fT:h,aI:i||0,nDA:j}}function installStaticTearOff(a,b,c,d,e,f,g,h){var t=tearOffParameters(a,true,false,c,d,e,f,g,h,false)
var s=staticTearOffGetter(t)
a[b]=s}function installInstanceTearOff(a,b,c,d,e,f,g,h,i,j){c=!!c
var t=tearOffParameters(a,false,c,d,e,f,g,h,i,!!j)
var s=instanceTearOffGetter(c,t)
a[b]=s}function setOrUpdateInterceptorsByTag(a){var t=v.interceptorsByTag
if(!t){v.interceptorsByTag=a
return}copyProperties(a,t)}function setOrUpdateLeafTags(a){var t=v.leafTags
if(!t){v.leafTags=a
return}copyProperties(a,t)}function updateTypes(a){var t=v.types
var s=t.length
t.push.apply(t,a)
return s}function updateHolder(a,b){copyProperties(b,a)
return a}var hunkHelpers=function(){var t=function(a,b,c,d,e){return function(f,g,h,i){return installInstanceTearOff(f,g,a,b,c,d,[h],i,e,false)}},s=function(a,b,c,d){return function(e,f,g,h){return installStaticTearOff(e,f,a,b,c,[g],h,d)}}
return{inherit:inherit,inheritMany:inheritMany,mixin:mixinEasy,mixinHard:mixinHard,installStaticTearOff:installStaticTearOff,installInstanceTearOff:installInstanceTearOff,_instance_0u:t(0,0,null,["$0"],0),_instance_1u:t(0,1,null,["$1"],0),_instance_2u:t(0,2,null,["$2"],0),_instance_0i:t(1,0,null,["$0"],0),_instance_1i:t(1,1,null,["$1"],0),_instance_2i:t(1,2,null,["$2"],0),_static_0:s(0,null,["$0"],0),_static_1:s(1,null,["$1"],0),_static_2:s(2,null,["$2"],0),makeConstList:makeConstList,lazy:lazy,lazyFinal:lazyFinal,updateHolder:updateHolder,convertToFastObject:convertToFastObject,updateTypes:updateTypes,setOrUpdateInterceptorsByTag:setOrUpdateInterceptorsByTag,setOrUpdateLeafTags:setOrUpdateLeafTags}}()
function initializeDeferredHunk(a){x=v.types.length
a(hunkHelpers,v,w,$)}var J={
dr(a,b){var t=A.b(a,b.h("f<0>"))
t.$flags=1
return t},
ds(a,b){var t=u.U
return J.db(t.a(a),t.a(b))},
a0(a){if(typeof a=="number"){if(Math.floor(a)==a)return J.al.prototype
return J.aT.prototype}if(typeof a=="string")return J.S.prototype
if(a==null)return J.am.prototype
if(typeof a=="boolean")return J.aS.prototype
if(Array.isArray(a))return J.f.prototype
if(typeof a=="object"){if(a instanceof A.i){return a}else{return J.a8.prototype}}return a},
eD(a){if(a==null)return a
if(Array.isArray(a))return J.f.prototype
return a},
eE(a){if(typeof a=="string")return J.S.prototype
if(a==null)return a
if(Array.isArray(a))return J.f.prototype
return a},
eF(a){if(typeof a=="number")return J.a7.prototype
if(typeof a=="string")return J.S.prototype
if(a==null)return a
return a},
b7(a,b){if(a==null)return b==null
if(typeof a!="object")return b!=null&&a===b
return J.a0(a).C(a,b)},
db(a,b){return J.eF(a).u(a,b)},
E(a){return J.a0(a).gl(a)},
c6(a){return J.eD(a).gA(a)},
cp(a){return J.eE(a).gp(a)},
dc(a){return J.a0(a).gE(a)},
b8(a){return J.a0(a).i(a)},
aQ:function aQ(){},
aS:function aS(){},
am:function am(){},
a8:function a8(){},
f:function f(a){this.$ti=a},
aR:function aR(){},
bA:function bA(a){this.$ti=a},
F:function F(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
a7:function a7(){},
al:function al(){},
aT:function aT(){},
S:function S(){}},A={c8:function c8(){},
cz(a){return new A.aU("Field '"+a+"' has been assigned during initialization.")},
dt(a){return new A.aU("Field '"+a+"' has already been initialized.")},
O(a,b){a=a+b&536870911
a=a+((a&524287)<<10)&536870911
return a^a>>>6},
cc(a){a=a+((a&67108863)<<3)&536870911
a^=a>>>11
return a+((a&16383)<<15)&536870911},
cm(a){var t,s
for(t=$.y.length,s=0;s<t;++s)if(a===$.y[s])return!0
return!1},
c7(){return new A.bS("No element")},
aU:function aU(a){this.a=a},
bR:function bR(){},
ak:function ak(){},
M:function M(){},
as:function as(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
au:function au(a,b,c){this.a=a
this.b=b
this.$ti=c},
k:function k(a,b,c){this.a=a
this.b=b
this.$ti=c},
aA:function aA(a,b,c){this.a=a
this.b=b
this.$ti=c},
dl(a,b,c){var t,s,r,q,p,o,n,m=A.Q(a),l=A.bD(new A.ap(a,m.h("ap<1>")),!0,b),k=l.length,j=0
for(;;){if(!(j<k)){t=!0
break}s=l[j]
if(typeof s!="string"||"__proto__"===s){t=!1
break}++j}if(t){r={}
for(q=0,j=0;j<l.length;l.length===k||(0,A.a2)(l),++j,q=p){s=l[j]
c.a(a.D(0,s))
p=q+1
r[s]=q}o=A.bD(new A.ar(a,m.h("ar<2>")),!0,c)
n=new A.aj(r,o,b.h("@<0>").G(c).h("aj<1,2>"))
n.$keys=l
return n}return new A.ai(A.dv(a,b,c),b.h("@<0>").G(c).h("ai<1,2>"))},
d8(a){var t=A.d7(a)
if(t!=null)return t
return"minified:"+a},
m(a){var t
if(typeof a=="string")return a
if(typeof a=="number"){if(a!==0)return""+a}else if(!0===a)return"true"
else if(!1===a)return"false"
else if(a==null)return"null"
t=J.b8(a)
return t},
aV(a){var t,s=$.cB
if(s==null)s=$.cB=Symbol("identityHashCode")
t=a[s]
if(t==null){t=Math.random()*0x3fffffff|0
a[s]=t}return t},
dE(a,b){var t,s=/^\s*[+-]?((0x[a-f0-9]+)|(\d+)|([a-z0-9]+))\s*$/i.exec(a)
if(s==null)return null
if(3>=s.length)return A.a(s,3)
t=s[3]
if(t!=null)return parseInt(a,10)
if(s[2]!=null)return parseInt(a,16)
return null},
aW(a){var t,s,r,q,p
if(a instanceof A.i)return A.x(A.b6(a),null)
t=J.a0(a)
if(t!==B.j)s=t===B.k
else s=!0
if(s){r=B.h(a)
if(r!=="Object"&&r!=="")return r
q=a.constructor
if(typeof q=="function"){p=q.name
if(typeof p=="string"&&p!=="Object"&&p!=="")return p}}return A.x(A.b6(a),null)},
cD(a){var t,s,r
if(a==null||typeof a=="number"||A.cj(a))return J.b8(a)
if(typeof a=="string")return JSON.stringify(a)
if(a instanceof A.K)return a.i(0)
if(a instanceof A.Y)return a.a7(!0)
t=$.da()
for(s=0;s<1;++s){r=t[s].aT(a)
if(r!=null)return r}return"Instance of '"+A.aW(a)+"'"},
dy(){return Date.now()},
dD(){var t,s
if($.bJ!==0)return
$.bJ=1000
if(typeof window=="undefined")return
t=window
if(t==null)return
if(!!t.dartUseDateNowForTicks)return
s=t.performance
if(s==null)return
if(typeof s.now!="function")return
$.bJ=1e6
$.ca=new A.bI(s)},
dF(a,b,c,d,e,f,g,h,i){var t,s,r,q=b-1
if(0<=a&&a<100){a+=400
q-=4800}t=B.a.n(h,1000)
s=Date.UTC(a,q,c,d,e,f,g+B.a.k(h-t,1000))
r=!0
if(!isNaN(s))if(!(s<-864e13))if(!(s>864e13))r=s===864e13&&t!==0
if(r)return null
return s},
V(a){if(a.date===void 0)a.date=new Date(a.a)
return a.date},
D(a){var t=A.V(a).getUTCFullYear()+0
return t},
ax(a){var t=A.V(a).getUTCMonth()+1
return t},
aw(a){var t=A.V(a).getUTCDate()+0
return t},
dz(a){var t=A.V(a).getUTCHours()+0
return t},
dB(a){var t=A.V(a).getUTCMinutes()+0
return t},
dC(a){var t=A.V(a).getUTCSeconds()+0
return t},
dA(a){var t=A.V(a).getUTCMilliseconds()+0
return t},
cC(a){var t=A.V(a).getUTCDay()+0
return B.a.n(t+6,7)+1},
a(a,b){if(a==null)J.cp(a)
throw A.d(A.d4(a,b))},
d4(a,b){var t,s="index"
if(!A.d_(b))return new A.a4(!0,b,s,null)
t=J.cp(a)
if(b<0||b>=t)return A.dn(b,t,a,s)
return new A.aY(null,null,!0,b,s,"Value not in range")},
d(a){return A.p(a,new Error())},
p(a,b){var t
if(a==null)a=new A.bU()
b.dartException=a
t=A.eQ
if("defineProperty" in Object){Object.defineProperty(b,"message",{get:t})
b.name=""}else b.toString=t
return b},
eQ(){return J.b8(this.dartException)},
aK(a,b){throw A.p(a,b==null?new Error():b)},
cn(a,b,c){var t
if(b==null)b=0
if(c==null)c=0
t=Error()
A.aK(A.e6(a,b,c),t)},
e6(a,b,c){var t,s,r,q,p,o,n,m,l
if(typeof b=="string")t=b
else{s="[]=;add;removeWhere;retainWhere;removeRange;setRange;setInt8;setInt16;setInt32;setUint8;setUint16;setUint32;setFloat32;setFloat64".split(";")
r=s.length
q=b
if(q>r){c=q/r|0
q%=r}t=s[q]}p=typeof c=="string"?c:"modify;remove from;add to".split(";")[c]
o=u.j.b(a)?"list":"ByteData"
n=a.$flags|0
m="a "
if((n&4)!==0)l="constant "
else if((n&2)!==0){l="unmodifiable "
m="an "}else l=(n&1)!==0?"fixed-length ":""
return new A.b1("'"+t+"': Cannot "+p+" "+m+l+o)},
a2(a){throw A.d(A.G(a))},
d5(a){if(a==null)return J.E(a)
if(typeof a=="object")return A.aV(a)
return J.E(a)},
ef(a,b,c,d,e,f){u.Z.a(a)
switch(A.aJ(b)){case 0:return a.$0()
case 1:return a.$1(c)
case 2:return a.$2(c,d)
case 3:return a.$3(c,d,e)
case 4:return a.$4(c,d,e,f)}throw A.d(new A.bX("Unsupported number of arguments for wrapped closure"))},
ey(a,b){var t=a.$identity
if(!!t)return t
t=A.ez(a,b)
a.$identity=t
return t},
ez(a,b){var t
switch(b){case 0:t=a.$0
break
case 1:t=a.$1
break
case 2:t=a.$2
break
case 3:t=a.$3
break
case 4:t=a.$4
break
default:t=null}if(t!=null)return t.bind(a)
return function(c,d,e){return function(f,g,h,i){return e(c,d,f,g,h,i)}}(a,b,A.ef)},
dk(a1){var t,s,r,q,p,o,n,m,l,k,j=a1.co,i=a1.iS,h=a1.iI,g=a1.nDA,f=a1.aI,e=a1.fs,d=a1.cs,c=e[0],b=d[0],a=j[c],a0=a1.fT
a0.toString
t=i?Object.create(new A.aZ().constructor.prototype):Object.create(new A.a5(null,null).constructor.prototype)
t.$initialize=t.constructor
s=i?function static_tear_off(){this.$initialize()}:function tear_off(a2,a3){this.$initialize(a2,a3)}
t.constructor=s
s.prototype=t
t.$_name=c
t.$_target=a
r=!i
if(r)q=A.cv(c,a,h,g)
else{t.$static_name=c
q=a}t.$S=A.dg(a0,i,h)
t[b]=q
for(p=q,o=1;o<e.length;++o){n=e[o]
if(typeof n=="string"){m=j[n]
l=n
n=m}else l=""
k=d[o]
if(k!=null){if(r)n=A.cv(l,n,h,g)
t[k]=n}if(o===f)p=n}t.$C=p
t.$R=a1.rC
t.$D=a1.dV
return s},
dg(a,b,c){if(typeof a=="number")return a
if(typeof a=="string"){if(b)throw A.d("Cannot compute signature for static tearoff.")
return function(d,e){return function(){return e(this,d)}}(a,A.de)}throw A.d("Error in functionType of tearoff")},
dh(a,b,c,d){var t=A.cu
switch(b?-1:a){case 0:return function(e,f){return function(){return f(this)[e]()}}(c,t)
case 1:return function(e,f){return function(g){return f(this)[e](g)}}(c,t)
case 2:return function(e,f){return function(g,h){return f(this)[e](g,h)}}(c,t)
case 3:return function(e,f){return function(g,h,i){return f(this)[e](g,h,i)}}(c,t)
case 4:return function(e,f){return function(g,h,i,j){return f(this)[e](g,h,i,j)}}(c,t)
case 5:return function(e,f){return function(g,h,i,j,k){return f(this)[e](g,h,i,j,k)}}(c,t)
default:return function(e,f){return function(){return e.apply(f(this),arguments)}}(d,t)}},
cv(a,b,c,d){if(c)return A.dj(a,b,d)
return A.dh(b.length,d,a,b)},
di(a,b,c,d){var t=A.cu,s=A.df
switch(b?-1:a){case 0:throw A.d(new A.bQ("Intercepted function with no arguments."))
case 1:return function(e,f,g){return function(){return f(this)[e](g(this))}}(c,s,t)
case 2:return function(e,f,g){return function(h){return f(this)[e](g(this),h)}}(c,s,t)
case 3:return function(e,f,g){return function(h,i){return f(this)[e](g(this),h,i)}}(c,s,t)
case 4:return function(e,f,g){return function(h,i,j){return f(this)[e](g(this),h,i,j)}}(c,s,t)
case 5:return function(e,f,g){return function(h,i,j,k){return f(this)[e](g(this),h,i,j,k)}}(c,s,t)
case 6:return function(e,f,g){return function(h,i,j,k,l){return f(this)[e](g(this),h,i,j,k,l)}}(c,s,t)
default:return function(e,f,g){return function(){var r=[g(this)]
Array.prototype.push.apply(r,arguments)
return e.apply(f(this),r)}}(d,s,t)}},
dj(a,b,c){var t,s
if($.cs==null)$.cs=A.cr("interceptor")
if($.ct==null)$.ct=A.cr("receiver")
t=b.length
s=A.di(t,c,a,b)
return s},
cl(a){return A.dk(a)},
de(a,b){return A.aH(v.typeUniverse,A.b6(a.a),b)},
cu(a){return a.a},
df(a){return a.b},
cr(a){var t,s,r,q=new A.a5("receiver","interceptor"),p=Object.getOwnPropertyNames(q)
p.$flags=1
t=p
for(p=t.length,s=0;s<p;++s){r=t[s]
if(q[r]===a)return r}throw A.d(A.cq("Field name "+a+" not found."))},
eA(a){var t,s=A.b([],u.s)
if(a==null)return s
if(Array.isArray(a)){for(t=0;t<a.length;++t)s.push(String(a[t]))
return s}s.push(String(a))
return s},
eB(a,b){var t=b.length,s=v.rttc[""+t+";"+a]
if(s==null)return null
if(t===0)return s
if(t===s.length)return s.apply(null,b)
return s(b)},
ad:function ad(a,b){this.a=a
this.b=b},
ai:function ai(a,b){this.a=a
this.$ti=b},
ah:function ah(){},
aj:function aj(a,b,c){this.a=a
this.b=b
this.$ti=c},
bI:function bI(a){this.a=a},
ay:function ay(){},
K:function K(){},
aM:function aM(){},
aN:function aN(){},
b0:function b0(){},
aZ:function aZ(){},
a5:function a5(a,b){this.a=a
this.b=b},
bQ:function bQ(a){this.a=a},
T:function T(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
bB:function bB(a,b){this.a=a
this.b=b
this.c=null},
ap:function ap(a,b){this.a=a
this.$ti=b},
ao:function ao(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
ar:function ar(a,b){this.a=a
this.$ti=b},
aq:function aq(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
Y:function Y(){},
ac:function ac(){},
cb(a,b){var t=b.c
return t==null?b.c=A.aF(a,"cx",[b.x]):t},
cF(a){var t=a.w
if(t===6||t===7)return A.cF(a.x)
return t===11||t===12},
dH(a){return a.as},
b5(a){return A.c_(v.typeUniverse,a,!1)},
Z(a0,a1,a2,a3){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a=a1.w
switch(a){case 5:case 1:case 2:case 3:case 4:return a1
case 6:t=a1.x
s=A.Z(a0,t,a2,a3)
if(s===t)return a1
return A.cN(a0,s,!0)
case 7:t=a1.x
s=A.Z(a0,t,a2,a3)
if(s===t)return a1
return A.cM(a0,s,!0)
case 8:r=a1.y
q=A.af(a0,r,a2,a3)
if(q===r)return a1
return A.aF(a0,a1.x,q)
case 9:p=a1.x
o=A.Z(a0,p,a2,a3)
n=a1.y
m=A.af(a0,n,a2,a3)
if(o===p&&m===n)return a1
return A.cf(a0,o,m)
case 10:l=a1.x
k=a1.y
j=A.af(a0,k,a2,a3)
if(j===k)return a1
return A.cO(a0,l,j)
case 11:i=a1.x
h=A.Z(a0,i,a2,a3)
g=a1.y
f=A.ev(a0,g,a2,a3)
if(h===i&&f===g)return a1
return A.cL(a0,h,f)
case 12:e=a1.y
a3+=e.length
d=A.af(a0,e,a2,a3)
p=a1.x
o=A.Z(a0,p,a2,a3)
if(d===e&&o===p)return a1
return A.cg(a0,o,d,!0)
case 13:c=a1.x
if(c<a3)return a1
b=a2[c-a3]
if(b==null)return a1
return b
default:throw A.d(A.aL("Attempted to substitute unexpected RTI kind "+a))}},
af(a,b,c,d){var t,s,r,q,p=b.length,o=A.c0(p)
for(t=!1,s=0;s<p;++s){r=b[s]
q=A.Z(a,r,c,d)
if(q!==r)t=!0
o[s]=q}return t?o:b},
ew(a,b,c,d){var t,s,r,q,p,o,n=b.length,m=A.c0(n)
for(t=!1,s=0;s<n;s+=3){r=b[s]
q=b[s+1]
p=b[s+2]
o=A.Z(a,p,c,d)
if(o!==p)t=!0
m.splice(s,3,r,q,o)}return t?m:b},
ev(a,b,c,d){var t,s=b.a,r=A.af(a,s,c,d),q=b.b,p=A.af(a,q,c,d),o=b.c,n=A.ew(a,o,c,d)
if(r===s&&p===q&&n===o)return b
t=new A.b2()
t.a=r
t.b=p
t.c=n
return t},
b(a,b){a[v.arrayRti]=b
return a},
d3(a){var t=a.$S
if(t!=null){if(typeof t=="number")return A.eH(t)
return a.$S()}return null},
eI(a,b){var t
if(A.cF(b))if(a instanceof A.K){t=A.d3(a)
if(t!=null)return t}return A.b6(a)},
b6(a){if(a instanceof A.i)return A.Q(a)
if(Array.isArray(a))return A.j(a)
return A.ci(J.a0(a))},
j(a){var t=a[v.arrayRti],s=u.r
if(t==null)return s
if(t.constructor!==s.constructor)return s
return t},
Q(a){var t=a.$ti
return t!=null?t:A.ci(a)},
ci(a){var t=a.constructor,s=t.$ccache
if(s!=null)return s
return A.ed(a,t)},
ed(a,b){var t=a instanceof A.K?Object.getPrototypeOf(Object.getPrototypeOf(a)).constructor:b,s=A.dX(v.typeUniverse,t.name)
b.$ccache=s
return s},
eH(a){var t,s=v.types,r=s[a]
if(typeof r=="string"){t=A.c_(v.typeUniverse,r,!1)
s[a]=t
return t}return r},
eG(a){return A.a_(A.Q(a))},
ck(a){var t
if(a instanceof A.Y)return A.eC(a.$r,a.a6())
t=a instanceof A.K?A.d3(a):null
if(t!=null)return t
if(u.R.b(a))return J.dc(a).a
if(Array.isArray(a))return A.j(a)
return A.b6(a)},
a_(a){var t=a.r
return t==null?a.r=new A.bZ(a):t},
eC(a,b){var t,s,r=b,q=r.length
if(q===0)return u.F
if(0>=q)return A.a(r,0)
t=A.aH(v.typeUniverse,A.ck(r[0]),"@<0>")
for(s=1;s<q;++s){if(!(s<r.length))return A.a(r,s)
t=A.cQ(v.typeUniverse,t,A.ck(r[s]))}return A.aH(v.typeUniverse,t,a)},
eR(a){return A.a_(A.c_(v.typeUniverse,a,!1))},
ec(a){var t=this
t.b=A.eu(t)
return t.b(a)},
eu(a){var t,s,r,q,p
if(a===u.K)return A.el
if(A.a1(a))return A.ep
t=a.w
if(t===6)return A.ea
if(t===1)return A.d1
if(t===7)return A.eg
s=A.et(a)
if(s!=null)return s
if(t===8){r=a.x
if(a.y.every(A.a1)){a.f="$i"+r
if(r==="z")return A.ej
if(a===u.m)return A.ei
return A.eo}}else if(t===10){q=A.eB(a.x,a.y)
p=q==null?A.d1:q
return p==null?A.cV(p):p}return A.e8},
et(a){if(a.w===8){if(a===u.S)return A.d_
if(a===u.i||a===u.H)return A.ek
if(a===u.N)return A.en
if(a===u.y)return A.cj}return null},
eb(a){var t=this,s=A.e7
if(A.a1(t))s=A.e5
else if(t===u.K)s=A.cV
else if(A.ag(t)){s=A.e9
if(t===u.t)s=A.e1
else if(t===u.x)s=A.e4
else if(t===u.u)s=A.e_
else if(t===u.c)s=A.cU
else if(t===u.I)s=A.e0
else if(t===u.E)s=A.e3}else if(t===u.S)s=A.aJ
else if(t===u.N)s=A.cW
else if(t===u.y)s=A.dZ
else if(t===u.H)s=A.cT
else if(t===u.i)s=A.ch
else if(t===u.m)s=A.e2
t.a=s
return t.a(a)},
e8(a){var t=this
if(a==null)return A.ag(t)
return A.eK(v.typeUniverse,A.eI(a,t),t)},
ea(a){if(a==null)return!0
return this.x.b(a)},
eo(a){var t,s=this
if(a==null)return A.ag(s)
t=s.f
if(a instanceof A.i)return!!a[t]
return!!J.a0(a)[t]},
ej(a){var t,s=this
if(a==null)return A.ag(s)
if(typeof a!="object")return!1
if(Array.isArray(a))return!0
t=s.f
if(a instanceof A.i)return!!a[t]
return!!J.a0(a)[t]},
ei(a){var t=this
if(a==null)return!1
if(typeof a=="object"){if(a instanceof A.i)return!!a[t.f]
return!0}if(typeof a=="function")return!0
return!1},
d0(a){if(typeof a=="object"){if(a instanceof A.i)return u.m.b(a)
return!0}if(typeof a=="function")return!0
return!1},
e7(a){var t=this
if(a==null){if(A.ag(t))return a}else if(t.b(a))return a
throw A.p(A.cX(a,t),new Error())},
e9(a){var t=this
if(a==null||t.b(a))return a
throw A.p(A.cX(a,t),new Error())},
cX(a,b){return new A.b4("TypeError: "+A.cH(a,A.x(b,null)))},
cH(a,b){return A.bn(a)+": type '"+A.x(A.ck(a),null)+"' is not a subtype of type '"+b+"'"},
A(a,b){return new A.b4("TypeError: "+A.cH(a,b))},
eg(a){var t=this
return t.x.b(a)||A.cb(v.typeUniverse,t).b(a)},
el(a){return a!=null},
cV(a){if(a!=null)return a
throw A.p(A.A(a,"Object"),new Error())},
ep(a){return!0},
e5(a){return a},
d1(a){return!1},
cj(a){return!0===a||!1===a},
dZ(a){if(!0===a)return!0
if(!1===a)return!1
throw A.p(A.A(a,"bool"),new Error())},
e_(a){if(!0===a)return!0
if(!1===a)return!1
if(a==null)return a
throw A.p(A.A(a,"bool?"),new Error())},
ch(a){if(typeof a=="number")return a
throw A.p(A.A(a,"double"),new Error())},
e0(a){if(typeof a=="number")return a
if(a==null)return a
throw A.p(A.A(a,"double?"),new Error())},
d_(a){return typeof a=="number"&&Math.floor(a)===a},
aJ(a){if(typeof a=="number"&&Math.floor(a)===a)return a
throw A.p(A.A(a,"int"),new Error())},
e1(a){if(typeof a=="number"&&Math.floor(a)===a)return a
if(a==null)return a
throw A.p(A.A(a,"int?"),new Error())},
ek(a){return typeof a=="number"},
cT(a){if(typeof a=="number")return a
throw A.p(A.A(a,"num"),new Error())},
cU(a){if(typeof a=="number")return a
if(a==null)return a
throw A.p(A.A(a,"num?"),new Error())},
en(a){return typeof a=="string"},
cW(a){if(typeof a=="string")return a
throw A.p(A.A(a,"String"),new Error())},
e4(a){if(typeof a=="string")return a
if(a==null)return a
throw A.p(A.A(a,"String?"),new Error())},
e2(a){if(A.d0(a))return a
throw A.p(A.A(a,"JSObject"),new Error())},
e3(a){if(a==null)return a
if(A.d0(a))return a
throw A.p(A.A(a,"JSObject?"),new Error())},
d2(a,b){var t,s,r
for(t="",s="",r=0;r<a.length;++r,s=", ")t+=s+A.x(a[r],b)
return t},
es(a,b){var t,s,r,q,p,o,n=a.x,m=a.y
if(""===n)return"("+A.d2(m,b)+")"
t=m.length
s=n.split(",")
r=s.length-t
for(q="(",p="",o=0;o<t;++o,p=", "){q+=p
if(r===0)q+="{"
q+=A.x(m[o],b)
if(r>=0)q+=" "+s[r];++r}return q+"})"},
cY(a2,a3,a4){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0=", ",a1=null
if(a4!=null){t=a4.length
if(a3==null)a3=A.b([],u.s)
else a1=a3.length
s=a3.length
for(r=t;r>0;--r)B.b.j(a3,"T"+(s+r))
for(q=u.O,p="<",o="",r=0;r<t;++r,o=a0){n=a3.length
m=n-1-r
if(!(m>=0))return A.a(a3,m)
p=p+o+a3[m]
l=a4[r]
k=l.w
if(!(k===2||k===3||k===4||k===5||l===q))p+=" extends "+A.x(l,a3)}p+=">"}else p=""
q=a2.x
j=a2.y
i=j.a
h=i.length
g=j.b
f=g.length
e=j.c
d=e.length
c=A.x(q,a3)
for(b="",a="",r=0;r<h;++r,a=a0)b+=a+A.x(i[r],a3)
if(f>0){b+=a+"["
for(a="",r=0;r<f;++r,a=a0)b+=a+A.x(g[r],a3)
b+="]"}if(d>0){b+=a+"{"
for(a="",r=0;r<d;r+=3,a=a0){b+=a
if(e[r+1])b+="required "
b+=A.x(e[r+2],a3)+" "+e[r]}b+="}"}if(a1!=null){a3.toString
a3.length=a1}return p+"("+b+") => "+c},
x(a,b){var t,s,r,q,p,o,n,m=a.w
if(m===5)return"erased"
if(m===2)return"dynamic"
if(m===3)return"void"
if(m===1)return"Never"
if(m===4)return"any"
if(m===6){t=a.x
s=A.x(t,b)
r=t.w
return(r===11||r===12?"("+s+")":s)+"?"}if(m===7)return"FutureOr<"+A.x(a.x,b)+">"
if(m===8){q=A.ex(a.x)
p=a.y
return p.length>0?q+("<"+A.d2(p,b)+">"):q}if(m===10)return A.es(a,b)
if(m===11)return A.cY(a,b,null)
if(m===12)return A.cY(a.x,b,a.y)
if(m===13){o=a.x
n=b.length
o=n-1-o
if(!(o>=0&&o<n))return A.a(b,o)
return b[o]}return"?"},
ex(a){var t=A.d7(a)
if(t!=null)return t
return"minified:"+a},
dY(a,b){var t=a.tR[b]
while(typeof t=="string")t=a.tR[t]
return t},
dX(a,b){var t,s,r,q,p,o=a.eT,n=o[b]
if(n==null)return A.c_(a,b,!1)
else if(typeof n=="number"){t=n
s=A.aG(a,5,"#")
r=A.c0(t)
for(q=0;q<t;++q)r[q]=s
p=A.aF(a,b,r)
o[b]=p
return p}else return n},
dW(a,b){return A.cR(a.tR,b)},
dV(a,b){return A.cR(a.eT,b)},
c_(a,b,c){var t,s=a.eC,r=s.get(b)
if(r!=null)return r
t=A.cP(a,null,b,!1)
s.set(b,t)
return t},
aH(a,b,c){var t,s,r=b.z
if(r==null)r=b.z=new Map()
t=r.get(c)
if(t!=null)return t
s=A.cP(a,b,c,!0)
r.set(c,s)
return s},
cQ(a,b,c){var t,s,r,q=b.Q
if(q==null)q=b.Q=new Map()
t=c.as
s=q.get(t)
if(s!=null)return s
r=A.cf(a,b,c.w===9?c.y:[c])
q.set(t,r)
return r},
cP(a,b,c,d){return A.dO(A.dI(a,b,c,d))},
P(a,b){b.a=A.eb
b.b=A.ec
return b},
aG(a,b,c){var t,s,r=a.eC.get(c)
if(r!=null)return r
t=new A.B(null,null)
t.w=b
t.as=c
s=A.P(a,t)
a.eC.set(c,s)
return s},
cN(a,b,c){var t,s=b.as+"?",r=a.eC.get(s)
if(r!=null)return r
t=A.dT(a,b,s,c)
a.eC.set(s,t)
return t},
dT(a,b,c,d){var t,s,r
if(d){t=b.w
s=!0
if(!A.a1(b))if(!(b===u.P||b===u.T))if(t!==6)s=t===7&&A.ag(b.x)
if(s)return b
else if(t===1)return u.P}r=new A.B(null,null)
r.w=6
r.x=b
r.as=c
return A.P(a,r)},
cM(a,b,c){var t,s=b.as+"/",r=a.eC.get(s)
if(r!=null)return r
t=A.dR(a,b,s,c)
a.eC.set(s,t)
return t},
dR(a,b,c,d){var t,s
if(d){t=b.w
if(A.a1(b)||b===u.K)return b
else if(t===1)return A.aF(a,"cx",[b])
else if(b===u.P||b===u.T)return u._}s=new A.B(null,null)
s.w=7
s.x=b
s.as=c
return A.P(a,s)},
dU(a,b){var t,s,r=""+b+"^",q=a.eC.get(r)
if(q!=null)return q
t=new A.B(null,null)
t.w=13
t.x=b
t.as=r
s=A.P(a,t)
a.eC.set(r,s)
return s},
aE(a){var t,s,r,q=a.length
for(t="",s="",r=0;r<q;++r,s=",")t+=s+a[r].as
return t},
dQ(a){var t,s,r,q,p,o=a.length
for(t="",s="",r=0;r<o;r+=3,s=","){q=a[r]
p=a[r+1]?"!":":"
t+=s+q+p+a[r+2].as}return t},
aF(a,b,c){var t,s,r,q=b
if(c.length>0)q+="<"+A.aE(c)+">"
t=a.eC.get(q)
if(t!=null)return t
s=new A.B(null,null)
s.w=8
s.x=b
s.y=c
if(c.length>0)s.c=c[0]
s.as=q
r=A.P(a,s)
a.eC.set(q,r)
return r},
cf(a,b,c){var t,s,r,q,p,o
if(b.w===9){t=b.x
s=b.y.concat(c)}else{s=c
t=b}r=t.as+(";<"+A.aE(s)+">")
q=a.eC.get(r)
if(q!=null)return q
p=new A.B(null,null)
p.w=9
p.x=t
p.y=s
p.as=r
o=A.P(a,p)
a.eC.set(r,o)
return o},
cO(a,b,c){var t,s,r="+"+(b+"("+A.aE(c)+")"),q=a.eC.get(r)
if(q!=null)return q
t=new A.B(null,null)
t.w=10
t.x=b
t.y=c
t.as=r
s=A.P(a,t)
a.eC.set(r,s)
return s},
cL(a,b,c){var t,s,r,q,p,o=b.as,n=c.a,m=n.length,l=c.b,k=l.length,j=c.c,i=j.length,h="("+A.aE(n)
if(k>0){t=m>0?",":""
h+=t+"["+A.aE(l)+"]"}if(i>0){t=m>0?",":""
h+=t+"{"+A.dQ(j)+"}"}s=o+(h+")")
r=a.eC.get(s)
if(r!=null)return r
q=new A.B(null,null)
q.w=11
q.x=b
q.y=c
q.as=s
p=A.P(a,q)
a.eC.set(s,p)
return p},
cg(a,b,c,d){var t,s=b.as+("<"+A.aE(c)+">"),r=a.eC.get(s)
if(r!=null)return r
t=A.dS(a,b,c,s,d)
a.eC.set(s,t)
return t},
dS(a,b,c,d,e){var t,s,r,q,p,o,n,m
if(e){t=c.length
s=A.c0(t)
for(r=0,q=0;q<t;++q){p=c[q]
if(p.w===1){s[q]=p;++r}}if(r>0){o=A.Z(a,b,s,0)
n=A.af(a,c,s,0)
return A.cg(a,o,n,c!==n)}}m=new A.B(null,null)
m.w=12
m.x=b
m.y=c
m.as=d
return A.P(a,m)},
dI(a,b,c,d){return{u:a,e:b,r:c,s:[],p:0,n:d}},
dO(a){var t,s,r,q,p,o,n,m=a.r,l=a.s
for(t=m.length,s=0;s<t;){r=m.charCodeAt(s)
if(r>=48&&r<=57)s=A.dK(s+1,r,m,l)
else if((((r|32)>>>0)-97&65535)<26||r===95||r===36||r===124)s=A.cJ(a,s,m,l,!1)
else if(r===46)s=A.cJ(a,s,m,l,!0)
else{++s
switch(r){case 44:break
case 58:l.push(!1)
break
case 33:l.push(!0)
break
case 59:l.push(A.X(a.u,a.e,l.pop()))
break
case 94:l.push(A.dU(a.u,l.pop()))
break
case 35:l.push(A.aG(a.u,5,"#"))
break
case 64:l.push(A.aG(a.u,2,"@"))
break
case 126:l.push(A.aG(a.u,3,"~"))
break
case 60:l.push(a.p)
a.p=l.length
break
case 62:A.dM(a,l)
break
case 38:A.dL(a,l)
break
case 63:q=a.u
l.push(A.cN(q,A.X(q,a.e,l.pop()),a.n))
break
case 47:q=a.u
l.push(A.cM(q,A.X(q,a.e,l.pop()),a.n))
break
case 40:l.push(-3)
l.push(a.p)
a.p=l.length
break
case 41:A.dJ(a,l)
break
case 91:l.push(a.p)
a.p=l.length
break
case 93:p=l.splice(a.p)
A.cK(a.u,a.e,p)
a.p=l.pop()
l.push(p)
l.push(-1)
break
case 123:l.push(a.p)
a.p=l.length
break
case 125:p=l.splice(a.p)
A.dP(a.u,a.e,p)
a.p=l.pop()
l.push(p)
l.push(-2)
break
case 43:o=m.indexOf("(",s)
l.push(m.substring(s,o))
l.push(-4)
l.push(a.p)
a.p=l.length
s=o+1
break
default:throw"Bad character "+r}}}n=l.pop()
return A.X(a.u,a.e,n)},
dK(a,b,c,d){var t,s,r=b-48
for(t=c.length;a<t;++a){s=c.charCodeAt(a)
if(!(s>=48&&s<=57))break
r=r*10+(s-48)}d.push(r)
return a},
cJ(a,b,c,d,e){var t,s,r,q,p,o,n=b+1
for(t=c.length;n<t;++n){s=c.charCodeAt(n)
if(s===46){if(e)break
e=!0}else{if(!((((s|32)>>>0)-97&65535)<26||s===95||s===36||s===124))r=s>=48&&s<=57
else r=!0
if(!r)break}}q=c.substring(b,n)
if(e){t=a.u
p=a.e
if(p.w===9)p=p.x
o=A.dY(t,p.x)[q]
if(o==null)A.aK('No "'+q+'" in "'+A.dH(p)+'"')
d.push(A.aH(t,p,o))}else d.push(q)
return n},
dM(a,b){var t,s=a.u,r=A.cI(a,b),q=b.pop()
if(typeof q=="string")b.push(A.aF(s,q,r))
else{t=A.X(s,a.e,q)
switch(t.w){case 11:b.push(A.cg(s,t,r,a.n))
break
default:b.push(A.cf(s,t,r))
break}}},
dJ(a,b){var t,s,r,q=a.u,p=b.pop(),o=null,n=null
if(typeof p=="number")switch(p){case-1:o=b.pop()
break
case-2:n=b.pop()
break
default:b.push(p)
break}else b.push(p)
t=A.cI(a,b)
p=b.pop()
switch(p){case-3:p=b.pop()
if(o==null)o=q.sEA
if(n==null)n=q.sEA
s=A.X(q,a.e,p)
r=new A.b2()
r.a=t
r.b=o
r.c=n
b.push(A.cL(q,s,r))
return
case-4:b.push(A.cO(q,b.pop(),t))
return
default:throw A.d(A.aL("Unexpected state under `()`: "+A.m(p)))}},
dL(a,b){var t=b.pop()
if(0===t){b.push(A.aG(a.u,1,"0&"))
return}if(1===t){b.push(A.aG(a.u,4,"1&"))
return}throw A.d(A.aL("Unexpected extended operation "+A.m(t)))},
cI(a,b){var t=b.splice(a.p)
A.cK(a.u,a.e,t)
a.p=b.pop()
return t},
X(a,b,c){if(typeof c=="string")return A.aF(a,c,a.sEA)
else if(typeof c=="number"){b.toString
return A.dN(a,b,c)}else return c},
cK(a,b,c){var t,s=c.length
for(t=0;t<s;++t)c[t]=A.X(a,b,c[t])},
dP(a,b,c){var t,s=c.length
for(t=2;t<s;t+=3)c[t]=A.X(a,b,c[t])},
dN(a,b,c){var t,s,r=b.w
if(r===9){if(c===0)return b.x
t=b.y
s=t.length
if(c<=s)return t[c-1]
c-=s
b=b.x
r=b.w}else if(c===0)return b
if(r!==8)throw A.d(A.aL("Indexed base must be an interface type"))
t=b.y
if(c<=t.length)return t[c-1]
throw A.d(A.aL("Bad index "+c+" for "+b.i(0)))},
eK(a,b,c){var t,s=b.d
if(s==null)s=b.d=new Map()
t=s.get(c)
if(t==null){t=A.n(a,b,null,c,null)
s.set(c,t)}return t},
n(a,b,c,d,e){var t,s,r,q,p,o,n,m,l,k,j
if(b===d)return!0
if(A.a1(d))return!0
t=b.w
if(t===4)return!0
if(A.a1(b))return!1
if(b.w===1)return!0
s=t===13
if(s)if(A.n(a,c[b.x],c,d,e))return!0
r=d.w
q=u.P
if(b===q||b===u.T){if(r===7)return A.n(a,b,c,d.x,e)
return d===q||d===u.T||r===6}if(d===u.K){if(t===7)return A.n(a,b.x,c,d,e)
return t!==6}if(t===7){if(!A.n(a,b.x,c,d,e))return!1
return A.n(a,A.cb(a,b),c,d,e)}if(t===6)return A.n(a,q,c,d,e)&&A.n(a,b.x,c,d,e)
if(r===7){if(A.n(a,b,c,d.x,e))return!0
return A.n(a,b,c,A.cb(a,d),e)}if(r===6)return A.n(a,b,c,q,e)||A.n(a,b,c,d.x,e)
if(s)return!1
q=t!==11
if((!q||t===12)&&d===u.Z)return!0
p=t===10
if(p&&d===u.J)return!0
if(r===12){if(b===u.g)return!0
if(t!==12)return!1
o=b.y
n=d.y
m=o.length
if(m!==n.length)return!1
c=c==null?o:o.concat(c)
e=e==null?n:n.concat(e)
for(l=0;l<m;++l){k=o[l]
j=n[l]
if(!A.n(a,k,c,j,e)||!A.n(a,j,e,k,c))return!1}return A.cZ(a,b.x,c,d.x,e)}if(r===11){if(b===u.g)return!0
if(q)return!1
return A.cZ(a,b,c,d,e)}if(t===8){if(r!==8)return!1
return A.eh(a,b,c,d,e)}if(p&&r===10)return A.em(a,b,c,d,e)
return!1},
cZ(a2,a3,a4,a5,a6){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1
if(!A.n(a2,a3.x,a4,a5.x,a6))return!1
t=a3.y
s=a5.y
r=t.a
q=s.a
p=r.length
o=q.length
if(p>o)return!1
n=o-p
m=t.b
l=s.b
k=m.length
j=l.length
if(p+k<o+j)return!1
for(i=0;i<p;++i){h=r[i]
if(!A.n(a2,q[i],a6,h,a4))return!1}for(i=0;i<n;++i){h=m[i]
if(!A.n(a2,q[p+i],a6,h,a4))return!1}for(i=0;i<j;++i){h=m[n+i]
if(!A.n(a2,l[i],a6,h,a4))return!1}g=t.c
f=s.c
e=g.length
d=f.length
for(c=0,b=0;b<d;b+=3){a=f[b]
for(;;){if(c>=e)return!1
a0=g[c]
c+=3
if(a<a0)return!1
a1=g[c-2]
if(a0<a){if(a1)return!1
continue}h=f[b+1]
if(a1&&!h)return!1
h=g[c-1]
if(!A.n(a2,f[b+2],a6,h,a4))return!1
break}}while(c<e){if(g[c+1])return!1
c+=3}return!0},
eh(a,b,c,d,e){var t,s,r,q,p,o=b.x,n=d.x
while(o!==n){t=a.tR[o]
if(t==null)return!1
if(typeof t=="string"){o=t
continue}s=t[n]
if(s==null)return!1
r=s.length
q=r>0?new Array(r):v.typeUniverse.sEA
for(p=0;p<r;++p)q[p]=A.aH(a,b,s[p])
return A.cS(a,q,null,c,d.y,e)}return A.cS(a,b.y,null,c,d.y,e)},
cS(a,b,c,d,e,f){var t,s=b.length
for(t=0;t<s;++t)if(!A.n(a,b[t],d,e[t],f))return!1
return!0},
em(a,b,c,d,e){var t,s=b.y,r=d.y,q=s.length
if(q!==r.length)return!1
if(b.x!==d.x)return!1
for(t=0;t<q;++t)if(!A.n(a,s[t],c,r[t],e))return!1
return!0},
ag(a){var t=a.w,s=!0
if(!(a===u.P||a===u.T))if(!A.a1(a))if(t!==6)s=t===7&&A.ag(a.x)
return s},
a1(a){var t=a.w
return t===2||t===3||t===4||t===5||a===u.O},
cR(a,b){var t,s,r=Object.keys(b),q=r.length
for(t=0;t<q;++t){s=r[t]
a[s]=b[s]}},
c0(a){return a>0?new Array(a):v.typeUniverse.sEA},
B:function B(a,b){var _=this
_.a=a
_.b=b
_.r=_.f=_.d=_.c=null
_.w=0
_.as=_.Q=_.z=_.y=_.x=null},
b2:function b2(){this.c=this.b=this.a=null},
bZ:function bZ(a){this.a=a},
bW:function bW(){},
b4:function b4(a){this.a=a},
du(a,b){return new A.T(a.h("@<0>").G(b).h("T<1,2>"))},
L(a,b){return new A.T(a.h("@<0>").G(b).h("T<1,2>"))},
dw(a){return new A.aB(a.h("aB<0>"))},
ce(){var t=Object.create(null)
t["<non-identifier-key>"]=t
delete t["<non-identifier-key>"]
return t},
dp(a,b){var t,s=A.j(a),r=new J.F(a,a.length,s.h("F<1>"))
if(r.m()){t=r.d
return t==null?s.c.a(t):t}return null},
dv(a,b,c){var t=A.du(b,c)
a.V(0,new A.bC(t,b,c))
return t},
bE(a){var t,s
if(A.cm(a))return"{...}"
t=new A.b_("")
try{s={}
B.b.j($.y,a)
t.a+="{"
s.a=!0
a.V(0,new A.bF(s,t))
t.a+="}"}finally{if(0>=$.y.length)return A.a($.y,-1)
$.y.pop()}s=t.a
return s.charCodeAt(0)==0?s:s},
aB:function aB(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
b3:function b3(a){this.a=a
this.b=null},
aC:function aC(a,b,c){var _=this
_.a=a
_.b=b
_.d=_.c=null
_.$ti=c},
bC:function bC(a,b,c){this.a=a
this.b=b
this.c=c},
at:function at(){},
bF:function bF(a,b){this.a=a
this.b=b},
aI:function aI(){},
a9:function a9(){},
az:function az(){},
ab:function ab(){},
aD:function aD(){},
ae:function ae(){},
eJ(a){var t=A.dE(a,null)
if(t!=null)return t
throw A.d(new A.bo(a))},
dx(a,b,c){var t,s
if(a<0||a>4294967295)A.aK(A.cE(a,0,4294967295,"length",null))
t=J.dr(new Array(a),c)
if(a!==0)for(s=0;s<t.length;++s)t[s]=b
return t},
bD(a,b,c){var t,s=A.b([],c.h("f<0>"))
for(t=J.c6(a);t.m();)B.b.j(s,c.a(t.gq()))
if(b)return s
s.$flags=1
return s},
U(a,b){var t,s
if(Array.isArray(a))return A.b(a.slice(0),b.h("f<0>"))
t=A.b([],b.h("f<0>"))
for(s=J.c6(a);s.m();)B.b.j(t,s.gq())
return t},
c9(a,b){var t=A.bD(a,!1,b)
t.$flags=3
return t},
cG(a,b,c){var t=J.c6(b)
if(!t.m())return a
if(c.length===0){do a+=A.m(t.gq())
while(t.m())}else{a+=A.m(t.gq())
while(t.m())a=a+c+A.m(t.gq())}return a},
t(a,b,c){var t=A.dF(a,b,c,0,0,0,0,0,!0)
return new A.o(t==null?new A.bf(a,b,c,0,0,0,0,0).$0():t,0,!0)},
dm(a){var t=Math.abs(a),s=a<0?"-":""
if(t>=1000)return""+a
if(t>=100)return s+"0"+t
if(t>=10)return s+"00"+t
return s+"000"+t},
cw(a){if(a>=100)return""+a
if(a>=10)return"0"+a
return"00"+a},
aO(a){if(a>=10)return""+a
return"0"+a},
bl(a,b,c){return new A.R(b+1000*c+864e8*a)},
bn(a){if(typeof a=="number"||A.cj(a)||a==null)return J.b8(a)
if(typeof a=="string")return JSON.stringify(a)
return A.cD(a)},
aL(a){return new A.b9(a)},
cq(a){return new A.a4(!1,null,null,a)},
dd(a,b,c){return new A.a4(!0,a,b,c)},
cE(a,b,c,d,e){return new A.aY(b,c,!0,a,d,"Invalid value")},
dn(a,b,c,d){return new A.bp(b,!0,a,d,"Index out of range")},
cd(a){return new A.b1(a)},
G(a){return new A.be(a)},
dq(a,b,c){var t,s
if(A.cm(a)){if(b==="("&&c===")")return"(...)"
return b+"..."+c}t=A.b([],u.s)
B.b.j($.y,a)
try{A.eq(a,t)}finally{if(0>=$.y.length)return A.a($.y,-1)
$.y.pop()}s=A.cG(b,u.V.a(t),", ")+c
return s.charCodeAt(0)==0?s:s},
cy(a,b,c){var t,s
if(A.cm(a))return b+"..."+c
t=new A.b_(b)
B.b.j($.y,a)
try{s=t
s.a=A.cG(s.a,a,", ")}finally{if(0>=$.y.length)return A.a($.y,-1)
$.y.pop()}t.a+=c
s=t.a
return s.charCodeAt(0)==0?s:s},
eq(a,b){var t,s,r,q,p,o,n,m=a.gA(a),l=0,k=0
for(;;){if(!(l<80||k<3))break
if(!m.m())return
t=A.m(m.gq())
B.b.j(b,t)
l+=t.length+2;++k}if(!m.m()){if(k<=5)return
if(0>=b.length)return A.a(b,-1)
s=b.pop()
if(0>=b.length)return A.a(b,-1)
r=b.pop()}else{q=m.gq();++k
if(!m.m()){if(k<=4){B.b.j(b,A.m(q))
return}s=A.m(q)
if(0>=b.length)return A.a(b,-1)
r=b.pop()
l+=s.length+2}else{p=m.gq();++k
for(;m.m();q=p,p=o){o=m.gq();++k
if(k>100){for(;;){if(!(l>75&&k>3))break
if(0>=b.length)return A.a(b,-1)
l-=b.pop().length+2;--k}B.b.j(b,"...")
return}}r=A.m(q)
s=A.m(p)
l+=s.length+r.length+4}}if(k>b.length+2){l+=5
n="..."}else n=null
for(;;){if(!(l>80&&b.length>3))break
if(0>=b.length)return A.a(b,-1)
l-=b.pop().length+2
if(n==null){l+=5
n="..."}}if(n!=null)B.b.j(b,n)
B.b.j(b,r)
B.b.j(b,s)},
cA(a,b,c,d){var t
if(B.d===c){t=B.a.gl(a)
b=J.E(b)
return A.cc(A.O(A.O($.c5(),t),b))}if(B.d===d){t=B.a.gl(a)
b=J.E(b)
c=J.E(c)
return A.cc(A.O(A.O(A.O($.c5(),t),b),c))}t=B.a.gl(a)
b=J.E(b)
c=J.E(c)
d=J.E(d)
d=A.cc(A.O(A.O(A.O(A.O($.c5(),t),b),c),d))
return d},
bf:function bf(a,b,c,d,e,f,g,h){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h},
o:function o(a,b,c){this.a=a
this.b=b
this.c=c},
R:function R(a){this.a=a},
bV:function bV(){},
bm:function bm(){},
b9:function b9(a){this.a=a},
bU:function bU(){},
a4:function a4(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
aY:function aY(a,b,c,d,e,f){var _=this
_.e=a
_.f=b
_.a=c
_.b=d
_.c=e
_.d=f},
bp:function bp(a,b,c,d,e){var _=this
_.f=a
_.a=b
_.b=c
_.c=d
_.d=e},
b1:function b1(a){this.a=a},
bS:function bS(a){this.a=a},
be:function be(a){this.a=a},
bH:function bH(){},
bX:function bX(a){this.a=a},
bo:function bo(a){this.a=a},
e:function e(){},
av:function av(){},
i:function i(){},
bT:function bT(){this.b=this.a=0},
b_:function b_(a){this.a=a},
aP:function aP(a,b){this.a=a
this.$ti=b},
eM(a,b,c){var t=A.j(a),s=t.h("k<1>"),r=A.U(new A.k(a,t.h("h(1)").a(new A.c3(b,c)),s),s.h("e.E"))
B.b.I(r,new A.c4())
return A.dp(r,u.f)},
eN(a,b){var t,s,r,q,p,o=A.U(a,a.$ti.h("M.E"))
B.b.ah(o)
t=o.length
if(t===0)return null
s=(t-1)*b
r=B.e.ac(s)
q=B.e.aD(s)
t=o.length
if(!(r>=0&&r<t))return A.a(o,r)
p=o[r]
if(!(q>=0&&q<t))return A.a(o,q)
return p+(o[q]-p)*(s-r)},
w:function w(a,b,c){this.d=a
this.a=b
this.b=c},
ba:function ba(a,b){this.a=a
this.b=b},
bb:function bb(a,b){this.a=a
this.b=b},
bc:function bc(a){this.a=a},
bd:function bd(){},
q:function q(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
c3:function c3(a,b){this.a=a
this.b=b},
c4:function c4(){},
N:function N(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.d=c
_.e=d
_.f=e},
bG:function bG(){},
l:function l(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.w=_.r=_.f=$},
bg:function bg(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.e=d
_.f=$
_.r=e
_.w=f},
bh:function bh(a,b,c){this.a=a
this.b=b
this.c=c},
bk:function bk(a,b){this.a=a
this.b=b},
bi:function bi(){},
bj:function bj(){},
bq:function bq(a,b,c,d){var _=this
_.a=a
_.e=$
_.f=b
_.r=c
_.z=_.x=_.w=$
_.as=d},
by:function by(a){this.a=a},
bz:function bz(a,b){this.a=a
this.b=b},
bw:function bw(a){this.a=a},
bt:function bt(a){this.a=a},
bu:function bu(a){this.a=a},
bv:function bv(){},
bx:function bx(a,b,c){this.a=a
this.b=b
this.c=c},
br:function br(a,b){this.a=a
this.b=b},
bs:function bs(a,b){this.a=a
this.b=b},
dG(a){var t,s,r,q=A.b([],u.q)
for(t=u.Q,s=0;s<7;++s)q.push(new A.I(B.c[s],A.b([],t),A.b([],t),A.b([],t),A.b([],t)))
t=a.a.c
r=t.t(-23328e8)
q=new A.aX(t,r,t,q)
q.aj(a)
return q},
I:function I(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e},
bM:function bM(a){this.a=a},
bL:function bL(){},
bK:function bK(){},
aX:function aX(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.e=_.d=$
_.f=d
_.r=0},
bN:function bN(){},
bO:function bO(a){this.a=a},
bP:function bP(){},
eL(a){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e={},d=a.length===0?1e4:A.eJ(B.b.gaL(a)),c=A.b([],u.h)
for(t=u.X,s=u.N,r=u.z,q=u.w,p=0;p<d;++p){o=B.a.n(p,20)
n=A.t(2025,1,1)
m=B.a.n(p,500)
n=n.t(864e8*m)
l=A.b([],q)
for(k=0;k<7;++k)l.push(B.a.n(p,4)===0&&k>=B.a.n(p,7)?null:A.t(2025,1,1).t(864e8*(m+(k+1)*5)))
m=A.L(s,r)
for(j=0;j<7;++j){i=B.c[j].b
m.v(0,i,i)}h=A.bD(l,!1,t)
h.$flags=3
c.push(new A.N(""+p,"Cliente "+o,n,h,A.dl(m,s,r)))}t=A.b([],u.o)
for(j=0;j<7;++j){k=B.c[j]
t.push(new A.q(k.b,k,A.t(2024,1,1),k.d))}s=A.t(2026,10,14)
r=u.S
q=u.L
o=u.A
c=A.c9(c,o)
t=A.c9(t,u.f)
n=u.D
g=new A.bT()
$.co()
g.a=$.ca.$0()
g.b=null
e.a=0
c=new A.c1(e,new A.bq(new A.bg(c,t,s,new A.ba(A.L(r,u.B),A.L(r,q)),A.L(u.W,u.C),A.L(o,u.t)),A.L(n,u.v),A.L(n,q),A.L(u.p,u.I)))
c.$0()
f=g.gaa()
c.$0()
A.eO("OP="+d+" inicial_ms="+f+" repeticion_ms="+(g.gaa()-f)+" checksum="+A.m(e.a))},
c1:function c1(a,b){this.a=a
this.b=b},
c2:function c2(){},
d7(a){return v.mangledGlobalNames[a]},
eO(a){if(typeof dartPrint=="function"){dartPrint(a)
return}if(typeof console=="object"&&typeof console.log!="undefined"){console.log(a)
return}if(typeof print=="function"){print(a)
return}throw"Unable to print message: "+String(a)},
eP(a){throw A.p(A.cz(a),new Error())},
d6(){throw A.p(A.dt(""),new Error())},
a3(){throw A.p(A.cz(""),new Error())}},B={}
var w=[A,J,B]
var $={}
A.c8.prototype={}
J.aQ.prototype={
C(a,b){return a===b},
gl(a){return A.aV(a)},
i(a){return"Instance of '"+A.aW(a)+"'"},
gE(a){return A.a_(A.ci(this))}}
J.aS.prototype={
i(a){return String(a)},
gl(a){return a?519018:218159},
gE(a){return A.a_(u.y)},
$iJ:1,
$ih:1}
J.am.prototype={
C(a,b){return null==b},
i(a){return"null"},
gl(a){return 0},
$iJ:1}
J.a8.prototype={$ian:1}
J.f.prototype={
j(a,b){A.j(a).c.a(b)
a.$flags&1&&A.cn(a,29)
a.push(b)},
aS(a,b){var t,s,r
A.j(a).h("1(1,1)").a(b)
t=a.length
if(t===0)throw A.d(A.c7())
if(0>=t)return A.a(a,0)
s=a[0]
for(r=1;r<t;++r){s=b.$2(s,a[r])
if(t!==a.length)throw A.d(A.G(a))}return s},
ad(a,b,c,d){var t,s,r
d.a(b)
A.j(a).G(d).h("1(1,2)").a(c)
t=a.length
for(s=b,r=0;r<t;++r){s=c.$2(s,a[r])
if(a.length!==t)throw A.d(A.G(a))}return s},
gaL(a){if(a.length>0)return a[0]
throw A.d(A.c7())},
gZ(a){var t=a.length
if(t>0)return a[t-1]
throw A.d(A.c7())},
aC(a,b){var t,s
A.j(a).h("h(1)").a(b)
t=a.length
for(s=0;s<t;++s){if(b.$1(a[s]))return!0
if(a.length!==t)throw A.d(A.G(a))}return!1},
aJ(a,b){var t,s
A.j(a).h("h(1)").a(b)
t=a.length
for(s=0;s<t;++s){if(!b.$1(a[s]))return!1
if(a.length!==t)throw A.d(A.G(a))}return!0},
I(a,b){var t,s,r,q,p,o=A.j(a)
o.h("c(1,1)?").a(b)
a.$flags&2&&A.cn(a,"sort")
t=a.length
if(t<2)return
if(b==null)b=J.ee()
if(t===2){s=a[0]
r=a[1]
if(b.$2(s,r)>0){a[0]=r
a[1]=s}return}q=0
if(o.c.b(null))for(p=0;p<a.length;++p)if(a[p]===void 0){a[p]=null;++q}a.sort(A.ey(b,2))
if(q>0)this.az(a,q)},
ah(a){return this.I(a,null)},
az(a,b){var t,s=a.length
for(;t=s-1,s>0;s=t)if(a[t]===null){a[t]=void 0;--b
if(b===0)break}},
i(a){return A.cy(a,"[","]")},
gA(a){return new J.F(a,a.length,A.j(a).h("F<1>"))},
gl(a){return A.aV(a)},
gp(a){return a.length},
v(a,b,c){A.j(a).c.a(c)
a.$flags&2&&A.cn(a)
if(!(b>=0&&b<a.length))throw A.d(A.d4(a,b))
a[b]=c},
aM(a,b){var t
A.j(a).h("h(1)").a(b)
if(0>=a.length)return-1
for(t=0;t<a.length;++t)if(b.$1(a[t]))return t
return-1},
$ie:1,
$iz:1}
J.aR.prototype={
aT(a){var t,s,r
if(!Array.isArray(a))return null
t=a.$flags|0
if((t&4)!==0)s="const, "
else if((t&2)!==0)s="unmodifiable, "
else s=(t&1)!==0?"fixed, ":""
r="Instance of '"+A.aW(a)+"'"
if(s==="")return r
return r+" ("+s+"length: "+a.length+")"}}
J.bA.prototype={}
J.F.prototype={
gq(){var t=this.d
return t==null?this.$ti.c.a(t):t},
m(){var t,s=this,r=s.a,q=r.length
if(s.b!==q){r=A.a2(r)
throw A.d(r)}t=s.c
if(t>=q){s.d=null
return!1}s.d=r[t]
s.c=t+1
return!0},
$iC:1}
J.a7.prototype={
u(a,b){var t
A.cT(b)
if(a<b)return-1
else if(a>b)return 1
else if(a===b){if(a===0){t=this.gY(b)
if(this.gY(a)===t)return 0
if(this.gY(a))return-1
return 1}return 0}else if(isNaN(a)){if(isNaN(b))return 0
return 1}else return-1},
gY(a){return a===0?1/a<0:a<0},
aD(a){var t,s
if(a>=0){if(a<=2147483647){t=a|0
return a===t?t:t+1}}else if(a>=-2147483648)return a|0
s=Math.ceil(a)
if(isFinite(s))return s
throw A.d(A.cd(""+a+".ceil()"))},
ac(a){var t,s
if(a>=0){if(a<=2147483647)return a|0}else if(a>=-2147483648){t=a|0
return a===t?t:t-1}s=Math.floor(a)
if(isFinite(s))return s
throw A.d(A.cd(""+a+".floor()"))},
i(a){if(a===0&&1/a<0)return"-0.0"
else return""+a},
gl(a){var t,s,r,q,p=a|0
if(a===p)return p&536870911
t=Math.abs(a)
s=Math.log(t)/0.6931471805599453|0
r=Math.pow(2,s)
q=t<1?t/r:r/t
return((q*9007199254740992|0)+(q*3542243181176521|0))*599197+s*1259&536870911},
n(a,b){var t=a%b
if(t===0)return 0
if(t>0)return t
return t+b},
k(a,b){return(a|0)===a?a/b|0:this.aA(a,b)},
aA(a,b){var t=a/b
if(t>=-2147483648&&t<=2147483647)return t|0
if(t>0){if(t!==1/0)return Math.floor(t)}else if(t>-1/0)return Math.ceil(t)
throw A.d(A.cd("Result of truncating division is "+A.m(t)+": "+A.m(a)+" ~/ "+b))},
gE(a){return A.a_(u.H)},
$iv:1,
$ir:1,
$iu:1}
J.al.prototype={
gE(a){return A.a_(u.S)},
$iJ:1,
$ic:1}
J.aT.prototype={
gE(a){return A.a_(u.i)},
$iJ:1}
J.S.prototype={
ag(a,b){var t,s
if(0>=b)return""
if(b===1||a.length===0)return a
if(b!==b>>>0)throw A.d(B.i)
for(t=a,s="";;){if((b&1)===1)s=t+s
b=b>>>1
if(b===0)break
t+=t}return s},
aR(a,b,c){var t=b-a.length
if(t<=0)return a
return this.ag(c,t)+a},
u(a,b){var t
A.cW(b)
if(a===b)t=0
else t=a<b?-1:1
return t},
i(a){return a},
gl(a){var t,s,r
for(t=a.length,s=0,r=0;r<t;++r){s=s+a.charCodeAt(r)&536870911
s=s+((s&524287)<<10)&536870911
s^=s>>6}s=s+((s&67108863)<<3)&536870911
s^=s>>11
return s+((s&16383)<<15)&536870911},
gE(a){return A.a_(u.N)},
gp(a){return a.length},
$iJ:1,
$iv:1,
$iW:1}
A.aU.prototype={
i(a){return"LateInitializationError: "+this.a}}
A.bR.prototype={}
A.ak.prototype={}
A.M.prototype={
gA(a){return new A.as(this,this.a.length,this.$ti.h("as<M.E>"))}}
A.as.prototype={
gq(){var t=this.d
return t==null?this.$ti.c.a(t):t},
m(){var t,s=this,r=s.a,q=r.a,p=q.length
if(s.b!==p)throw A.d(A.G(r))
t=s.c
if(t>=p){s.d=null
return!1}s.d=r.b.$1(q[t]);++s.c
return!0},
$iC:1}
A.au.prototype={
gp(a){return this.a.length}}
A.k.prototype={
gA(a){var t=this.a
return new A.aA(new J.F(t,t.length,A.j(t).h("F<1>")),this.b,this.$ti.h("aA<1>"))}}
A.aA.prototype={
m(){var t,s,r,q
for(t=this.a,s=this.b,r=t.$ti.c;t.m();){q=t.d
if(s.$1(q==null?r.a(q):q))return!0}return!1},
gq(){var t=this.a,s=t.d
return s==null?t.$ti.c.a(s):s},
$iC:1}
A.ad.prototype={$r:"+(1,2)",$s:1}
A.ai.prototype={}
A.ah.prototype={
i(a){return A.bE(this)},
$iH:1}
A.aj.prototype={
gp(a){return this.b.length},
gau(){var t=this.$keys
if(t==null){t=Object.keys(this.a)
this.$keys=t}return t},
T(a){if("__proto__"===a)return!1
return this.a.hasOwnProperty(a)},
D(a,b){if(!this.T(b))return null
return this.b[this.a[b]]},
V(a,b){var t,s,r,q
this.$ti.h("~(1,2)").a(b)
t=this.gau()
s=this.b
for(r=t.length,q=0;q<r;++q)b.$2(t[q],s[q])}}
A.bI.prototype={
$0(){return B.e.ac(1000*this.a.now())},
$S:2}
A.ay.prototype={}
A.K.prototype={
i(a){var t=this.constructor,s=t==null?null:t.name
return"Closure '"+A.d8(s==null?"unknown":s)+"'"},
$ia6:1,
gaU(){return this},
$C:"$1",
$R:1,
$D:null}
A.aM.prototype={$C:"$0",$R:0}
A.aN.prototype={$C:"$2",$R:2}
A.b0.prototype={}
A.aZ.prototype={
i(a){var t=this.$static_name
if(t==null)return"Closure of unknown static method"
return"Closure '"+A.d8(t)+"'"}}
A.a5.prototype={
C(a,b){if(b==null)return!1
if(this===b)return!0
if(!(b instanceof A.a5))return!1
return this.$_target===b.$_target&&this.a===b.a},
gl(a){return(A.d5(this.a)^A.aV(this.$_target))>>>0},
i(a){return"Closure '"+this.$_name+"' of "+("Instance of '"+A.aW(this.a)+"'")}}
A.bQ.prototype={
i(a){return"RuntimeError: "+this.a}}
A.T.prototype={
gp(a){return this.a},
T(a){var t
if(typeof a=="number"&&(a&0x3fffffff)===a){t=this.c
if(t==null)return!1
return t[a]!=null}else return this.aN(a)},
aN(a){var t=this.d
if(t==null)return!1
return this.W(this.a5(t,a),a)>=0},
D(a,b){var t,s,r,q,p=null
if(typeof b=="string"){t=this.b
if(t==null)return p
s=t[b]
r=s==null?p:s.b
return r}else if(typeof b=="number"&&(b&0x3fffffff)===b){q=this.c
if(q==null)return p
s=q[b]
r=s==null?p:s.b
return r}else return this.aO(b)},
aO(a){var t,s,r=this.d
if(r==null)return null
t=this.a5(r,a)
s=this.W(t,a)
if(s<0)return null
return t[s].b},
v(a,b,c){var t,s,r=this,q=A.Q(r)
q.c.a(b)
q.y[1].a(c)
if(typeof b=="string"){t=r.b
r.a2(t==null?r.b=r.R():t,b,c)}else if(typeof b=="number"&&(b&0x3fffffff)===b){s=r.c
r.a2(s==null?r.c=r.R():s,b,c)}else r.aP(b,c)},
aP(a,b){var t,s,r,q,p=this,o=A.Q(p)
o.c.a(a)
o.y[1].a(b)
t=p.d
if(t==null)t=p.d=p.R()
s=p.ae(a)
r=t[s]
if(r==null)t[s]=[p.N(a,b)]
else{q=p.W(r,a)
if(q>=0)r[q].b=b
else r.push(p.N(a,b))}},
F(a,b){var t,s,r=this,q=A.Q(r)
q.c.a(a)
q.h("2()").a(b)
if(r.T(a)){t=r.D(0,a)
return t==null?q.y[1].a(t):t}s=b.$0()
r.v(0,a,s)
return s},
V(a,b){var t,s,r=this
A.Q(r).h("~(1,2)").a(b)
t=r.e
s=r.r
while(t!=null){b.$2(t.a,t.b)
if(s!==r.r)throw A.d(A.G(r))
t=t.c}},
a2(a,b,c){var t,s=A.Q(this)
s.c.a(b)
s.y[1].a(c)
t=a[b]
if(t==null)a[b]=this.N(b,c)
else t.b=c},
N(a,b){var t=this,s=A.Q(t),r=new A.bB(s.c.a(a),s.y[1].a(b))
if(t.e==null)t.e=t.f=r
else t.f=t.f.c=r;++t.a
t.r=t.r+1&1073741823
return r},
ae(a){return J.E(a)&1073741823},
a5(a,b){return a[this.ae(b)]},
W(a,b){var t,s
if(a==null)return-1
t=a.length
for(s=0;s<t;++s)if(J.b7(a[s].a,b))return s
return-1},
i(a){return A.bE(this)},
R(){var t=Object.create(null)
t["<non-identifier-key>"]=t
delete t["<non-identifier-key>"]
return t}}
A.bB.prototype={}
A.ap.prototype={
gp(a){return this.a.a},
gA(a){var t=this.a
return new A.ao(t,t.r,t.e,this.$ti.h("ao<1>"))}}
A.ao.prototype={
gq(){return this.d},
m(){var t,s=this,r=s.a
if(s.b!==r.r)throw A.d(A.G(r))
t=s.c
if(t==null){s.d=null
return!1}else{s.d=t.a
s.c=t.c
return!0}},
$iC:1}
A.ar.prototype={
gp(a){return this.a.a},
gA(a){var t=this.a
return new A.aq(t,t.r,t.e,this.$ti.h("aq<1>"))}}
A.aq.prototype={
gq(){return this.d},
m(){var t,s=this,r=s.a
if(s.b!==r.r)throw A.d(A.G(r))
t=s.c
if(t==null){s.d=null
return!1}else{s.d=t.b
s.c=t.c
return!0}},
$iC:1}
A.Y.prototype={
i(a){return this.a7(!1)},
a7(a){var t,s,r,q,p,o=this.ar(),n=this.a6(),m=(a?"Record ":"")+"("
for(t=o.length,s="",r=0;r<t;++r,s=", "){m+=s
q=o[r]
if(typeof q=="string")m=m+q+": "
if(!(r<n.length))return A.a(n,r)
p=n[r]
m=a?m+A.cD(p):m+A.m(p)}m+=")"
return m.charCodeAt(0)==0?m:m},
ar(){var t,s=this.$s
while($.bY.length<=s)B.b.j($.bY,null)
t=$.bY[s]
if(t==null){t=this.al()
B.b.v($.bY,s,t)}return t},
al(){var t,s,r,q=this.$r,p=q.indexOf("("),o=q.substring(1,p),n=q.substring(p),m=n==="()"?0:n.replace(/[^,]/g,"").length+1,l=A.b(new Array(m),u.G)
for(t=0;t<m;++t)l[t]=t
if(o!==""){s=o.split(",")
t=s.length
for(r=m;t>0;){--r;--t
B.b.v(l,r,s[t])}}return A.c9(l,u.K)}}
A.ac.prototype={
a6(){return[this.a,this.b]},
C(a,b){if(b==null)return!1
return b instanceof A.ac&&this.$s===b.$s&&J.b7(this.a,b.a)&&J.b7(this.b,b.b)},
gl(a){return A.cA(this.$s,this.a,this.b,B.d)}}
A.B.prototype={
h(a){return A.aH(v.typeUniverse,this,a)},
G(a){return A.cQ(v.typeUniverse,this,a)}}
A.b2.prototype={}
A.bZ.prototype={
i(a){return A.x(this.a,null)}}
A.bW.prototype={
i(a){return this.a}}
A.b4.prototype={}
A.aB.prototype={
gA(a){var t=this,s=new A.aC(t,t.r,t.$ti.h("aC<1>"))
s.c=t.e
return s},
gp(a){return this.a},
aF(a,b){var t=this.am(b)
return t},
am(a){var t=this.d
if(t==null)return!1
return this.a4(t[a.gl(0)&1073741823],a)>=0},
j(a,b){var t,s,r=this
r.$ti.c.a(b)
if(typeof b=="string"&&b!=="__proto__"){t=r.b
return r.a3(t==null?r.b=A.ce():t,b)}else if(typeof b=="number"&&(b&1073741823)===b){s=r.c
return r.a3(s==null?r.c=A.ce():s,b)}else return r.ak(b)},
ak(a){var t,s,r,q=this
q.$ti.c.a(a)
t=q.d
if(t==null)t=q.d=A.ce()
s=J.E(a)&1073741823
r=t[s]
if(r==null)t[s]=[q.S(a)]
else{if(q.a4(r,a)>=0)return!1
r.push(q.S(a))}return!0},
a3(a,b){this.$ti.c.a(b)
if(u.a.a(a[b])!=null)return!1
a[b]=this.S(b)
return!0},
S(a){var t=this,s=new A.b3(t.$ti.c.a(a))
if(t.e==null)t.e=t.f=s
else t.f=t.f.b=s;++t.a
t.r=t.r+1&1073741823
return s},
a4(a,b){var t,s
if(a==null)return-1
t=a.length
for(s=0;s<t;++s)if(J.b7(a[s].a,b))return s
return-1}}
A.b3.prototype={}
A.aC.prototype={
gq(){var t=this.d
return t==null?this.$ti.c.a(t):t},
m(){var t=this,s=t.c,r=t.a
if(t.b!==r.r)throw A.d(A.G(r))
else if(s==null){t.d=null
return!1}else{t.d=t.$ti.h("1?").a(s.a)
t.c=s.b
return!0}},
$iC:1}
A.bC.prototype={
$2(a,b){this.a.v(0,this.b.a(a),this.c.a(b))},
$S:4}
A.at.prototype={
gp(a){return this.a},
i(a){return A.bE(this)},
$iH:1}
A.bF.prototype={
$2(a,b){var t,s=this.a
if(!s.a)this.b.a+=", "
s.a=!1
s=this.b
t=A.m(a)
s.a=(s.a+=t)+": "
t=A.m(b)
s.a+=t},
$S:5}
A.aI.prototype={}
A.a9.prototype={
D(a,b){return this.a.D(0,b)},
gp(a){return this.a.a},
i(a){return A.bE(this.a)},
$iH:1}
A.az.prototype={}
A.ab.prototype={
i(a){return A.cy(this,"{","}")},
$ie:1,
$iaa:1}
A.aD.prototype={}
A.ae.prototype={}
A.bf.prototype={
$0(){var t=this
return A.aK(A.cq("("+t.a+", "+t.b+", "+t.c+", "+t.d+", "+t.e+", "+t.f+", "+t.r+", "+t.w+")"))},
$S:6}
A.o.prototype={
t(a){var t=1000,s=B.a.n(a,t),r=B.a.k(a-s,t),q=this.b+s,p=B.a.n(q,t),o=this.a+B.a.k(q-p,t)+r
if(o<-864e13||o>864e13)A.aK(A.cE(o,-864e13,864e13,"millisecondsSinceEpoch",null))
if(o===864e13&&p!==0)A.aK(A.dd(p,"microsecond","Time including microseconds is outside valid range"))
return new A.o(o,p,!0)},
a9(a){return A.bl(0,this.b-a.b,this.a-a.a)},
C(a,b){var t
if(b==null)return!1
t=!1
if(b instanceof A.o)if(this.a===b.a)t=this.b===b.b
return t},
gl(a){return A.cA(this.a,this.b,B.d,B.d)},
L(a){var t=this.a,s=a.a
if(t<=s)t=t===s&&this.b>a.b
else t=!0
return t},
u(a,b){var t
u.k.a(b)
t=B.a.u(this.a,b.a)
if(t!==0)return t
return B.a.u(this.b,b.b)},
i(a){var t=this,s=A.dm(A.D(t)),r=A.aO(A.ax(t)),q=A.aO(A.aw(t)),p=A.aO(A.dz(t)),o=A.aO(A.dB(t)),n=A.aO(A.dC(t)),m=A.cw(A.dA(t)),l=t.b,k=l===0?"":A.cw(l)
return s+"-"+r+"-"+q+" "+p+":"+o+":"+n+"."+m+k+"Z"},
$iv:1}
A.R.prototype={
C(a,b){if(b==null)return!1
return b instanceof A.R&&this.a===b.a},
gl(a){return B.a.gl(this.a)},
u(a,b){return B.a.u(this.a,u.d.a(b).a)},
i(a){var t,s,r,q,p,o=this.a,n=B.a.k(o,36e8),m=o%36e8
if(o<0){n=0-n
o=0-m
t="-"}else{o=m
t=""}s=B.a.k(o,6e7)
o%=6e7
r=s<10?"0":""
q=B.a.k(o,1e6)
p=q<10?"0":""
return t+n+":"+r+s+":"+p+q+"."+B.f.aR(B.a.i(o%1e6),6,"0")},
$iv:1}
A.bV.prototype={
i(a){return this.ap()}}
A.bm.prototype={}
A.b9.prototype={
i(a){var t=this.a
if(t!=null)return"Assertion failed: "+A.bn(t)
return"Assertion failed"}}
A.bU.prototype={}
A.a4.prototype={
gP(){return"Invalid argument"+(!this.a?"(s)":"")},
gO(){return""},
i(a){var t=this,s=t.c,r=s==null?"":" ("+s+")",q=t.d,p=q==null?"":": "+q,o=t.gP()+r+p
if(!t.a)return o
return o+t.gO()+": "+A.bn(t.gX())},
gX(){return this.b}}
A.aY.prototype={
gX(){return A.cU(this.b)},
gP(){return"RangeError"},
gO(){var t,s=this.e,r=this.f
if(s==null)t=r!=null?": Not less than or equal to "+A.m(r):""
else if(r==null)t=": Not greater than or equal to "+A.m(s)
else if(r>s)t=": Not in inclusive range "+A.m(s)+".."+A.m(r)
else t=r<s?": Valid value range is empty":": Only valid value is "+A.m(s)
return t}}
A.bp.prototype={
gX(){return A.aJ(this.b)},
gP(){return"RangeError"},
gO(){if(A.aJ(this.b)<0)return": index must not be negative"
var t=this.f
if(t===0)return": no indices are valid"
return": index should be less than "+t},
gp(a){return this.f}}
A.b1.prototype={
i(a){return"Unsupported operation: "+this.a}}
A.bS.prototype={
i(a){return"Bad state: "+this.a}}
A.be.prototype={
i(a){var t=this.a
if(t==null)return"Concurrent modification during iteration."
return"Concurrent modification during iteration: "+A.bn(t)+"."}}
A.bH.prototype={
i(a){return"Out of Memory"}}
A.bX.prototype={
i(a){return"Exception: "+this.a}}
A.bo.prototype={
i(a){var t=this.a,s=""!==t?"FormatException: "+t:"FormatException"
return s}}
A.e.prototype={
gp(a){var t,s=this.gA(this)
for(t=0;s.m();)++t
return t},
i(a){return A.dq(this,"(",")")}}
A.av.prototype={
gl(a){return A.i.prototype.gl.call(this,0)},
i(a){return"null"}}
A.i.prototype={$ii:1,
C(a,b){return this===b},
gl(a){return A.aV(this)},
i(a){return"Instance of '"+A.aW(this)+"'"},
gE(a){return A.eG(this)},
toString(){return this.i(this)}}
A.bT.prototype={
gaa(){var t,s=this.b
if(s==null)s=$.ca.$0()
t=s-this.a
if($.co()===1000)return t
return B.a.k(t,1000)}}
A.b_.prototype={
gp(a){return this.a.length},
i(a){var t=this.a
return t.charCodeAt(0)==0?t:t}}
A.aP.prototype={
i(a){return"Expando:null"}}
A.w.prototype={
ap(){return"ProcesoCiclo."+this.b}}
A.ba.prototype={
aw(a){return this.b.F(a,new A.bb(this,a))},
aK(a){return this.a.F(a,new A.bc(a))},
ai(a,b){var t,s,r,q=A.t(A.D(a),A.ax(a),A.aw(a))
if(b<=0)return q
t=b*2+14
while(this.B(q,q.t(864e8*t))<b)t*=2
for(s=1;s<t;){r=B.a.k(s+t,2)
if(this.B(q,q.t(864e8*r))>=b)t=r
else s=r+1}return q.t(A.bl(s,0,0).a)},
B(a,b){var t,s,r,q,p,o,n,m,l,k,j,i,h=864e8,g=A.t(A.D(a),A.ax(a),A.aw(a)),f=A.t(A.D(b),A.ax(b),A.aw(b))
if(!f.L(g))return 0
for(t=A.D(g),s=g.a,r=g.b,q=f.a,p=f.b,o=0;t<=A.D(f);++t){n=this.aw(t)
m=A.t(t,1,1)
l=t===A.D(g)?B.a.k(r-m.b+1000*(s-m.a),h)+1:0
k=t===A.D(f)?B.a.k(p-m.b+1000*(q-m.a),h)+1:n.length-1
j=n.length
if(!(k>=0&&k<j))return A.a(n,k)
i=n[k]
if(!(l>=0&&l<j))return A.a(n,l)
o+=i-n[l]}return o}}
A.bb.prototype={
$0(){var t,s,r,q,p=this.b,o=A.t(p,1,1),n=B.a.k(A.t(p+1,1,1).a9(o).a,864e8),m=A.dx(n+1,0,u.S)
for(p=this.a,t=0;t<n;t=s){s=t+1
r=m[t]
q=o.t(864e8*t)
B.b.v(m,s,r+(A.cC(q)<=5&&!p.aK(A.D(q)).aF(0,A.t(A.D(q),A.ax(q),A.aw(q)))?1:0))}return m},
$S:7}
A.bc.prototype={
$0(){var t,s,r,q,p,o,n=new A.bd(),m=this.a,l=B.a.n(m,19),k=B.a.k(m,100),j=B.a.n(m,100),i=B.a.k(k,4),h=B.a.n(k,4),g=B.a.n(19*l+k-i-B.a.k(k-B.a.k(k+8,25)+1,3)+15,30),f=B.a.n(32+2*h+2*B.a.k(j,4)-g-B.a.n(j,4),7),e=g+f-7*B.a.k(l+11*g+22*f,451)+114,d=A.t(m,B.a.k(e,31),B.a.n(e,31)+1),c=A.dw(u.k)
for(t=u.Y,s=[A.b([1,1],t),A.b([5,1],t),A.b([7,20],t),A.b([8,7],t),A.b([12,8],t),A.b([12,25],t)],r=0;r<6;++r){q=s[r]
p=q.length
if(0>=p)return A.a(q,0)
o=q[0]
if(1>=p)return A.a(q,1)
c.j(0,A.t(m,o,q[1]))}for(t=[A.b([1,6],t),A.b([3,19],t),A.b([6,29],t),A.b([8,15],t),A.b([10,12],t),A.b([11,1],t),A.b([11,11],t)],r=0;r<7;++r){q=t[r]
s=q.length
if(0>=s)return A.a(q,0)
p=q[0]
if(1>=s)return A.a(q,1)
c.j(0,n.$1(A.t(m,p,q[1])))}c.j(0,d.t(-2592e8))
c.j(0,d.t(-1728e8))
for(m=[39,60,68],r=0;r<3;++r)c.j(0,n.$1(d.t(864e8*m[r])))
return c},
$S:8}
A.bd.prototype={
$1(a){return a.t(A.bl(B.a.n(8-A.cC(a),7),0,0).a)},
$S:9}
A.q.prototype={}
A.c3.prototype={
$1(a){var t
u.f.a(a)
if(a.b===this.a){t=this.b
t=!a.c.L(A.t(A.D(t),A.ax(t),A.aw(t)))}else t=!1
return t},
$S:10}
A.c4.prototype={
$2(a,b){var t=u.f
t.a(a)
return t.a(b).c.u(0,a.c)},
$S:11}
A.N.prototype={
K(a){var t,s=a.a
if(s===0)s=this.d
else{t=this.e;--s
if(!(s>=0&&s<t.length))return A.a(t,s)
s=t[s]}return s},
gaE(){var t=B.b.aJ(this.e,new A.bG())
return t}}
A.bG.prototype={
$1(a){return u.X.a(a)!=null},
$S:3}
A.l.prototype={
gH(){var t,s,r,q=this,p=q.f
if(p===$){t=q.a
s=q.b
if(t.K(s)==null||q.c==null)r=null
else{t=t.K(s)
t.toString
r=q.d.ai(t,q.c.d)}q.f!==$&&A.a3()
p=q.f=r}return p},
gaH(){var t,s,r,q,p,o=this,n=o.r
if(n===$){t=o.a
s=o.b
if(t.K(s)!=null){r=t.e
q=s.a
if(!(q<r.length))return A.a(r,q)
q=r[q]==null
r=q}else r=!0
if(r)p=null
else{r=t.K(s)
r.toString
t=t.e
s=s.a
if(!(s<t.length))return A.a(t,s)
s=t[s]
s.toString
p=o.d.B(r,s)}o.r!==$&&A.a3()
n=o.r=p}return n},
gJ(){var t,s,r,q,p=this,o=p.w
if(o===$){t=p.gH()
if(t!=null){s=p.a.e
r=p.b.a
if(!(r<s.length))return A.a(s,r)
r=s[r]==null
s=r}else s=!0
if(s)q=null
else{s=p.a.e
r=p.b.a
if(!(r<s.length))return A.a(s,r)
q=!s[r].L(t)}p.w!==$&&A.a3()
o=p.w=q}return o}}
A.bg.prototype={
gav(){var t,s,r,q,p,o=this,n=o.f
if(n===$){t=A.L(u.N,u.f)
for(s=o.b,r=s.length,q=0;q<r;++q){p=s[q]
t.v(0,p.a,p)}o.f!==$&&A.a3()
o.f=t
n=t}return n},
M(a,b){return this.r.F(new A.ad(a,b),new A.bh(this,a,b))},
a0(a){return this.w.F(a,new A.bk(this,a))}}
A.bh.prototype={
$0(){var t=this.a,s=this.b,r=this.c,q=t.gav().D(0,s.f.D(0,r.b)),p=(q==null?null:q.b)===r?q:null
return new A.l(s,r,p,t.e,t.c)},
$S:12}
A.bk.prototype={
$0(){var t,s,r,q=A.b([],u.l)
for(t=this.a,s=this.b,r=0;r<7;++r)q.push(t.M(s,B.c[r]).c)
if(B.b.aC(q,new A.bi()))return null
return B.b.ad(q,3,new A.bj(),u.S)},
$S:13}
A.bi.prototype={
$1(a){return u.M.a(a)==null},
$S:14}
A.bj.prototype={
$2(a,b){return A.aJ(a)+u.M.a(b).d},
$S:15}
A.bq.prototype={
ga1(){var t,s,r,q,p=this,o=p.e
if(o===$){t=p.a.a
s=A.j(t)
r=s.h("k<1>")
q=A.U(new A.k(t,s.h("h(1)").a(new A.by(p)),r),r.h("e.E"))
p.e!==$&&A.a3()
p.e=q
o=q}return o},
ab(a){var t=!1
if(a!=null)t=!a.L(this.a.c)
return t},
af(a){return this.f.F(a,new A.bz(this,a))},
ga8(){var t,s,r,q,p=this,o=p.w
if(o===$){t=p.ga1()
s=A.j(t)
r=s.h("k<1>")
q=A.U(new A.k(t,s.h("h(1)").a(new A.bw(p)),r),r.h("e.E"))
p.w!==$&&A.a3()
p.w=q
o=q}return o},
aI(a){var t=B.b.gZ(a.e)
t.toString
return this.a.e.B(a.d,t)},
ao(){var t=this.ga8(),s=A.j(t),r=s.h("k<1>"),q=A.U(new A.k(t,s.h("h(1)").a(new A.bt(this)),r),r.h("e.E"))
if(q.length===0)return null
t=A.j(q)
return 100*new A.k(q,t.h("h(1)").a(new A.bu(this)),t.h("k<1>")).gp(0)/q.length},
aq(){var t,s,r,q,p,o,n,m,l,k=A.b([],u.n)
for(t=this.ga8(),s=t.length,r=this.a,q=r.e,p=0;p<t.length;t.length===s||(0,A.a2)(t),++p){o=t[p]
n=r.a0(o)
if(n==null||n<=0)continue
m=B.b.gZ(o.e)
m.toString
l=q.B(o.d,m)-n
if(l>0)B.b.j(k,100*l/n)}return k.length===0?null:B.b.aS(k,new A.bv())/k.length},
aG(a){return this.as.F(new A.ad(a,!1),new A.bx(this,a,!1))},
an(a,b){var t,s,r,q=this.a,p=A.eM(q.b,a,q.c)
q=this.af(a)
t=A.j(q)
s=t.h("k<1>")
r=A.U(new A.k(q,t.h("h(1)").a(new A.br(!1,p)),s),s.h("e.E"))
if(r.length===0)return null
q=A.j(r)
return 100*new A.k(r,q.h("h(1)").a(new A.bs(!1,p)),q.h("k<1>")).gp(0)/r.length}}
A.by.prototype={
$1(a){u.A.a(a)
return!0},
$S:0}
A.bz.prototype={
$0(){var t,s,r,q,p,o,n,m,l,k,j,i=A.b([],u.Q)
for(t=this.a,s=t.ga1(),r=s.length,q=this.b,p=q.a,o=t.a,n=0;n<s.length;s.length===r||(0,A.a2)(s),++n){m=s[n]
l=m.e
k=l.length
if(!(p<k))return A.a(l,p)
if(t.ab(l[p])){if(p===0)l=m.d
else{j=p-1
if(!(j>=0&&j<k))return A.a(l,j)
j=l[j]
l=j}l=l!=null}else l=!1
if(l)i.push(o.M(m,q))}return i},
$S:16}
A.bw.prototype={
$1(a){u.A.a(a)
return a.gaE()&&this.a.ab(B.b.gZ(a.e))},
$S:0}
A.bt.prototype={
$1(a){return this.a.a.a0(u.A.a(a))!=null},
$S:0}
A.bu.prototype={
$1(a){var t,s
u.A.a(a)
t=this.a
s=t.aI(a)
t=t.a.a0(a)
t.toString
return s<=t},
$S:0}
A.bv.prototype={
$2(a,b){return A.ch(a)+A.ch(b)},
$S:17}
A.bx.prototype={
$0(){return this.a.an(this.b,this.c)},
$S:18}
A.br.prototype={
$1(a){var t=u.C.a(a).gJ()
return t!=null},
$S:1}
A.bs.prototype={
$1(a){var t=u.C.a(a).gJ()
t.toString
return t},
$S:1}
A.I.prototype={
ga_(){return B.b.ad(this.c,0,new A.bM(this),u.S)},
gU(){var t=this.d,s=A.j(t),r=s.h("k<1>")
t=A.U(new A.k(t,s.h("h(1)").a(new A.bL()),r),r.h("e.E"))
return t},
gaB(){var t=this.gU(),s=A.j(t)
return new A.k(t,s.h("h(1)").a(new A.bK()),s.h("k<1>")).gp(0)}}
A.bM.prototype={
$2(a,b){var t
A.aJ(a)
u.C.a(b)
t=b.gH()
t.toString
return Math.max(a,b.d.B(t,b.e))},
$S:19}
A.bL.prototype={
$1(a){return u.C.a(a).gJ()!=null},
$S:1}
A.bK.prototype={
$1(a){var t=u.C.a(a).gJ()
t.toString
return t},
$S:1}
A.aX.prototype={
aj(a5){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a=this,a0=a5.a,a1=a.c,a2=a.b,a3=B.a.k(a1.a9(a2).a,864e8),a4=a2.t(-864e8)
a.e!==$&&A.d6()
a.e=a4
a3=a2.t(0-A.bl(a3+1,0,0).a)
a.d!==$&&A.d6()
a.d=a3
for(t=a5.ga1(),s=t.length,r=a.f,q=a.a,p=q.a,q=q.b,o=a2.a,a2=a2.b,n=a1.a,a1=a1.b,m=0;m<t.length;t.length===s||(0,A.a2)(t),++m){l=t[m]
k=B.b.aM(l.e,new A.bN())
if(k>=0){if(!(k<7))return A.a(B.c,k)
j=a0.M(l,B.c[k])
i=j.a
h=j.b.a
g=h===0
if(g)f=i.d
else{f=i.e
e=h-1
if(!(e>=0&&e<f.length))return A.a(f,e)
e=f[e]
f=e}e=!0
if(f!=null){if(g)i=i.d
else{i=i.e;--h
if(!(h>=0&&h<i.length))return A.a(i,h)
h=i[h]
i=h}h=i.a
if(h<=p)i=h===p&&i.b>q
else i=e}else i=e
if(i)++a.r
else{if(!(k<r.length))return A.a(r,k)
d=r[k]
B.b.j(d.b,j)
i=j.gH()
if(i!=null){h=i.a
if(p<=h)i=p===h&&q>i.b
else i=!0}else i=!1
if(i)B.b.j(d.c,j)}}for(i=r.length,c=0;c<r.length;r.length===i||(0,A.a2)(r),++c){d=r[c]
j=a0.M(l,d.a)
h=j.a
g=j.b.a
if(g===0)f=h.d
else{f=h.e
e=g-1
if(!(e>=0&&e<f.length))return A.a(f,e)
e=f[e]
f=e}e=!0
if(f!=null){f=h.e
if(!(g<f.length))return A.a(f,g)
f=f[g]
if(f!=null){b=f.a
if(b<=p)f=b===p&&f.b>q
else f=e}else f=e}else f=e
if(f)continue
h=h.e
if(!(g<h.length))return A.a(h,g)
f=h[g]
e=f.a
if(e>=o)b=e===o&&f.b<a2
else b=!0
if(!b){if(e<=n)f=e===n&&f.b>a1
else f=!0
f=!f}else f=!1
if(f)B.b.j(d.d,j)
h=h[g]
g=h.a
f=a3.a
if(g>=f)f=g===f&&h.b<a3.b
else f=!0
if(!f){f=a4.a
if(g<=f)h=g===f&&h.b>a4.b
else h=!0
h=!h}else h=!1
if(h)B.b.j(d.e,j)}}for(a1=r.length,m=0;m<r.length;r.length===a1||(0,A.a2)(r),++m){d=r[m]
B.b.I(d.c,new A.bO(d))}},
gaQ(){var t=A.U(this.f,u.b)
B.b.I(t,new A.bP())
return t}}
A.bN.prototype={
$1(a){return u.X.a(a)==null},
$S:3}
A.bO.prototype={
$2(a,b){var t,s,r=u.C
r.a(a)
r.a(b)
r=b.gH()
r.toString
r=b.d.B(r,b.e)
t=a.gH()
t.toString
s=B.a.u(r,a.d.B(t,a.e))
return s!==0?s:B.f.u(a.a.a,b.a.a)},
$S:20}
A.bP.prototype={
$2(a,b){var t,s,r=u.b
r.a(a)
r.a(b)
t=B.a.u(b.c.length,a.c.length)
if(t!==0)return t
s=B.a.u(b.ga_(),a.ga_())
return s!==0?s:B.a.u(a.a.a,b.a.a)},
$S:21}
A.c1.prototype={
$0(){var t,s,r,q,p,o,n=this.a,m=n.a,l=this.b,k=l.x
if(k===$){t=l.ao()
l.x!==$&&A.a3()
l.x=t
k=t}s=m+(k==null?0:k)
n.a=s
k=l.z
if(k===$){t=l.aq()
l.z!==$&&A.a3()
l.z=t
k=t}m=n.a=s+(k==null?0:k)
for(r=0;r<7;++r,m=s){q=B.c[r]
p=l.aG(q)
s=m+(p==null?0:p)
n.a=s
m=l.af(q)
p=A.j(m)
p=A.eN(new A.au(m,p.h("c(1)").a(new A.c2()),p.h("au<1,c>")),0.8)
s+=p==null?0:p
n.a=s}m=$.d9()
p=m.a
o=p.get(l)
if(o==null){o=A.dG(l)
m.$ti.h("1?").a(o)
p.set(l,o)
m=o}else m=o
for(m=m.gaQ(),l=m.length,r=0;r<m.length;m.length===l||(0,A.a2)(m),++r){q=m[r]
s=n.a+q.ga_()
n.a=s
p=q.gU().length===0?null:100*q.gaB()/q.gU().length
n.a=s+(p==null?0:p)}},
$S:22}
A.c2.prototype={
$1(a){var t=u.C.a(a).gaH()
t.toString
return t},
$S:23};(function installTearOffs(){var t=hunkHelpers._static_2,s=hunkHelpers._static_0
t(J,"ee","ds",24)
s(A,"er","dy",2)})();(function inheritance(){var t=hunkHelpers.mixin,s=hunkHelpers.inherit,r=hunkHelpers.inheritMany
s(A.i,null)
r(A.i,[A.c8,J.aQ,A.ay,J.F,A.bm,A.bR,A.e,A.as,A.aA,A.Y,A.a9,A.ah,A.K,A.at,A.bB,A.ao,A.aq,A.B,A.b2,A.bZ,A.ab,A.b3,A.aC,A.aI,A.o,A.R,A.bV,A.bH,A.bX,A.bo,A.av,A.bT,A.b_,A.aP,A.ba,A.q,A.N,A.l,A.bg,A.bq,A.I,A.aX])
r(J.aQ,[J.aS,J.am,J.a8,J.a7,J.S])
s(J.f,J.a8)
s(J.aR,A.ay)
s(J.bA,J.f)
r(J.a7,[J.al,J.aT])
r(A.bm,[A.aU,A.bQ,A.bW,A.b9,A.bU,A.a4,A.b1,A.bS,A.be])
r(A.e,[A.ak,A.k])
r(A.ak,[A.M,A.ap,A.ar])
s(A.au,A.M)
s(A.ac,A.Y)
s(A.ad,A.ac)
s(A.ae,A.a9)
s(A.az,A.ae)
s(A.ai,A.az)
s(A.aj,A.ah)
r(A.K,[A.aM,A.aN,A.b0,A.bd,A.c3,A.bG,A.bi,A.by,A.bw,A.bt,A.bu,A.br,A.bs,A.bL,A.bK,A.bN,A.c2])
r(A.aM,[A.bI,A.bf,A.bb,A.bc,A.bh,A.bk,A.bz,A.bx,A.c1])
r(A.b0,[A.aZ,A.a5])
s(A.T,A.at)
s(A.b4,A.bW)
s(A.aD,A.ab)
s(A.aB,A.aD)
r(A.aN,[A.bC,A.bF,A.c4,A.bj,A.bv,A.bM,A.bO,A.bP])
r(A.a4,[A.aY,A.bp])
s(A.w,A.bV)
t(A.ae,A.aI)})()
var v={G:typeof self!="undefined"?self:globalThis,typeUniverse:{eC:new Map(),tR:{},eT:{},tPV:{},sEA:[]},mangledGlobalNames:{c:"int",r:"double",u:"num",W:"String",h:"bool",av:"Null",z:"List",i:"Object",H:"Map",an:"JSObject"},mangledNames:{},types:["h(N)","h(l)","c()","h(o?)","~(@,@)","~(i?,i?)","0&()","z<c>()","aa<o>()","o(o)","h(q)","c(q,q)","l()","c?()","h(q?)","c(c,q?)","z<l>()","r(r,r)","r?()","c(c,l)","c(l,l)","c(I,I)","~()","c(l)","c(@,@)"],arrayRti:Symbol("$ti"),rttc:{"2;":(a,b)=>c=>c instanceof A.ad&&a.b(c.a)&&b.b(c.b)}}
A.dW(v.typeUniverse,JSON.parse('{"aS":{"h":[],"J":[]},"am":{"J":[]},"a8":{"an":[]},"f":{"z":["1"],"an":[],"e":["1"]},"aR":{"ay":[]},"bA":{"f":["1"],"z":["1"],"an":[],"e":["1"]},"F":{"C":["1"]},"a7":{"r":[],"u":[],"v":["u"]},"al":{"r":[],"c":[],"u":[],"v":["u"],"J":[]},"aT":{"r":[],"u":[],"v":["u"],"J":[]},"S":{"W":[],"v":["W"],"J":[]},"ak":{"e":["1"]},"M":{"e":["1"]},"as":{"C":["1"]},"au":{"M":["2"],"e":["2"],"M.E":"2","e.E":"2"},"k":{"e":["1"],"e.E":"1"},"aA":{"C":["1"]},"ad":{"ac":[],"Y":[]},"ai":{"az":["1","2"],"ae":["1","2"],"a9":["1","2"],"aI":["1","2"],"H":["1","2"]},"ah":{"H":["1","2"]},"aj":{"ah":["1","2"],"H":["1","2"]},"K":{"a6":[]},"aM":{"a6":[]},"aN":{"a6":[]},"b0":{"a6":[]},"aZ":{"a6":[]},"a5":{"a6":[]},"T":{"at":["1","2"],"H":["1","2"]},"ap":{"e":["1"],"e.E":"1"},"ao":{"C":["1"]},"ar":{"e":["1"],"e.E":"1"},"aq":{"C":["1"]},"ac":{"Y":[]},"aB":{"ab":["1"],"aa":["1"],"e":["1"]},"aC":{"C":["1"]},"at":{"H":["1","2"]},"a9":{"H":["1","2"]},"az":{"ae":["1","2"],"a9":["1","2"],"aI":["1","2"],"H":["1","2"]},"ab":{"aa":["1"],"e":["1"]},"aD":{"ab":["1"],"aa":["1"],"e":["1"]},"o":{"v":["o"]},"r":{"u":[],"v":["u"]},"R":{"v":["R"]},"c":{"u":[],"v":["u"]},"z":{"e":["1"]},"u":{"v":["u"]},"aa":{"e":["1"]},"W":{"v":["W"]}}'))
A.dV(v.typeUniverse,JSON.parse('{"ak":1,"aD":1}'))
var u=(function rtii(){var t=A.b5
return{U:t("v<@>"),k:t("o"),d:t("R"),Z:t("a6"),V:t("e<@>"),Q:t("f<l>"),G:t("f<i>"),h:t("f<N>"),o:t("f<q>"),q:t("f<I>"),s:t("f<W>"),n:t("f<r>"),r:t("f<@>"),Y:t("f<c>"),w:t("f<o?>"),l:t("f<q?>"),T:t("am"),m:t("an"),g:t("eS"),v:t("z<l>"),j:t("z<@>"),L:t("z<c>"),C:t("l"),P:t("av"),K:t("i"),A:t("N"),f:t("q"),b:t("I"),D:t("w"),J:t("eU"),F:t("+()"),W:t("+(N,w)"),p:t("+(w,h)"),B:t("aa<o>"),N:t("W"),R:t("J"),y:t("h"),i:t("r"),z:t("@"),S:t("c"),X:t("o?"),_:t("cx<av>?"),E:t("an?"),O:t("i?"),M:t("q?"),x:t("W?"),a:t("b3?"),u:t("h?"),I:t("r?"),t:t("c?"),c:t("u?"),H:t("u")}})();(function constants(){var t=hunkHelpers.makeConstList
B.j=J.aQ.prototype
B.b=J.f.prototype
B.a=J.al.prototype
B.e=J.a7.prototype
B.f=J.S.prototype
B.k=J.a8.prototype
B.h=function getTagFallback(o) {
  var s = Object.prototype.toString.call(o);
  return s.substring(8, s.length - 1);
}
B.i=new A.bH()
B.d=new A.bR()
B.r=new A.w(6,0,"compras")
B.n=new A.w(3,1,"trazo")
B.o=new A.w(3,2,"corte")
B.q=new A.w(4,3,"separado")
B.l=new A.w(11,4,"aliados")
B.m=new A.w(2,5,"terminado")
B.p=new A.w(3,6,"logistica")
B.c=t([B.r,B.n,B.o,B.q,B.l,B.m,B.p],A.b5("f<w>"))
B.t=A.eR("i")})();(function staticFields(){$.y=A.b([],u.G)
$.cB=null
$.bJ=0
$.ca=A.er()
$.ct=null
$.cs=null
$.bY=A.b([],A.b5("f<z<i>?>"))})();(function lazyInitializers(){var t=hunkHelpers.lazyFinal
t($,"eX","da",()=>A.b([new J.aR()],A.b5("f<ay>")))
t($,"eW","c5",()=>A.d5(B.t))
t($,"eV","co",()=>{A.dD()
return $.bJ})
t($,"eT","d9",()=>new A.aP(new WeakMap(),A.b5("aP<aX>")))})();(function nativeSupport(){hunkHelpers.setOrUpdateInterceptorsByTag({})
hunkHelpers.setOrUpdateLeafTags({})})()
Function.prototype.$0=function(){return this()}
Function.prototype.$1=function(a){return this(a)}
Function.prototype.$2=function(a,b){return this(a,b)}
Function.prototype.$3=function(a,b,c){return this(a,b,c)}
Function.prototype.$4=function(a,b,c,d){return this(a,b,c,d)}
convertAllToFastObject(w)
convertToFastObject($);(function(a){if(typeof document==="undefined"){a(null)
return}if(typeof document.currentScript!="undefined"){a(document.currentScript)
return}var t=document.scripts
function onLoad(b){for(var r=0;r<t.length;++r){t[r].removeEventListener("load",onLoad,false)}a(b.target)}for(var s=0;s<t.length;++s){t[s].addEventListener("load",onLoad,false)}})(function(a){v.currentScript=a
var t=function(b){return A.eL(A.eA(b))}
if(typeof dartMainRunner==="function"){dartMainRunner(t,[])}else{t([])}})})()