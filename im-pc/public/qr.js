// Minimal QR Code encoder for Qingma public IDs.
// Supports QR Version 1-L alphanumeric payloads (up to 25 characters),
// which is enough for the app's public account identifier.
const ALPHA='0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:'

function bits(value,length){const out=[];for(let i=length-1;i>=0;i--)out.push((value>>i)&1);return out}
function gfTables(){const exp=new Array(512).fill(0),log=new Array(256).fill(0);let x=1;for(let i=0;i<255;i++){exp[i]=x;log[x]=i;x<<=1;if(x&0x100)x^=0x11d}for(let i=255;i<512;i++)exp[i]=exp[i-255];return{exp,log}}
const GF=gfTables()
function gfMul(a,b){if(a===0||b===0)return 0;return GF.exp[GF.log[a]+GF.log[b]]}
function generator(degree){let poly=[1];for(let i=0;i<degree;i++){const next=new Array(poly.length+1).fill(0);for(let j=0;j<poly.length;j++){next[j]^=poly[j];next[j+1]^=gfMul(poly[j],GF.exp[i])}poly=next}return poly}
function ecc(data,degree){const gen=generator(degree),rem=new Array(degree).fill(0);for(const value of data){const factor=value^rem[0];rem.shift();rem.push(0);for(let j=0;j<degree;j++)rem[j]^=gfMul(gen[j+1],factor)}return rem}
function bchTypeInfo(data){let d=data<<10;const g=0x537;while(msb(d)>=msb(g))d^=g<<(msb(d)-msb(g));return((data<<10)|d)^0x5412}
function msb(v){let n=0;while(v){n++;v>>>=1}return n}
function mask0(row,col){return(row+col)%2===0}
function placeFinder(m,row,col){const size=m.length;for(let r=-1;r<=7;r++)for(let c=-1;c<=7;c++){const rr=row+r,cc=col+c;if(rr<0||rr>=size||cc<0||cc>=size)continue;const dark=r>=0&&r<=6&&c>=0&&c<=6&&(r===0||r===6||c===0||c===6||(r>=2&&r<=4&&c>=2&&c<=4));m[rr][cc]=dark}}
function reserveFormat(m){const size=m.length;for(let i=0;i<15;i++){if(i<6)m[i][8]=false;else if(i<8)m[i+1][8]=false;else m[size-15+i][8]=false;if(i<8)m[8][size-i-1]=false;else if(i<9)m[8][15-i]=false;else m[8][15-i-1]=false}m[size-8][8]=true}
function writeFormat(m,mask=0){const size=m.length,bch=bchTypeInfo((1<<3)|mask);for(let i=0;i<15;i++){const dark=((bch>>i)&1)===1;if(i<6)m[i][8]=dark;else if(i<8)m[i+1][8]=dark;else m[size-15+i][8]=dark;if(i<8)m[8][size-i-1]=dark;else if(i<9)m[8][15-i]=dark;else m[8][15-i-1]=dark}m[size-8][8]=true}
function dataCodewords(text){const clean=String(text||'').toUpperCase().split('').filter(ch=>ALPHA.includes(ch)).join('').slice(0,25);if(!clean)throw new Error('二维码内容不能为空');const stream=[];stream.push(...bits(0b0010,4),...bits(clean.length,9));for(let i=0;i<clean.length;i+=2){if(i+1<clean.length)stream.push(...bits(ALPHA.indexOf(clean[i])*45+ALPHA.indexOf(clean[i+1]),11));else stream.push(...bits(ALPHA.indexOf(clean[i]),6))}const cap=19*8;stream.push(...new Array(Math.min(4,cap-stream.length)).fill(0));while(stream.length%8)stream.push(0);const data=[];for(let i=0;i<stream.length;i+=8)data.push(parseInt(stream.slice(i,i+8).join(''),2));let pad=true;while(data.length<19){data.push(pad?0xec:0x11);pad=!pad}return data}
function qrMatrix(text){const size=21,m=Array.from({length:size},()=>Array(size).fill(null));placeFinder(m,0,0);placeFinder(m,size-7,0);placeFinder(m,0,size-7);for(let i=8;i<size-8;i++){if(m[6][i]===null)m[6][i]=i%2===0;if(m[i][6]===null)m[i][6]=i%2===0}reserveFormat(m);const data=dataCodewords(text),all=[...data,...ecc(data,7)];let row=size-1,inc=-1,byte=0,bit=7;for(let col=size-1;col>0;col-=2){if(col===6)col--;while(true){for(let c=0;c<2;c++){const cc=col-c;if(m[row][cc]!==null)continue;let dark=false;if(byte<all.length)dark=((all[byte]>>bit)&1)===1;if(mask0(row,cc))dark=!dark;m[row][cc]=dark;bit--;if(bit<0){byte++;bit=7}}row+=inc;if(row<0||row>=size){row-=inc;inc=-inc;break}}}writeFormat(m,0);return m}
function qrPayload(user){const id=String(user?.public_id||user?.username||'').toUpperCase().replace(/[^0-9A-Z $%*+\-./:]/g,'').slice(0,25);return id||'QINGMA'}

window.ZcQr={qrMatrix,qrPayload};
