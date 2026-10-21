#include "doa.h"
#include <math.h>
#include <string.h>
#define N 2048
#define W 1024
#define LAG 16
#define PI 3.14159265358979323846f
typedef struct {float r,i;} Cpx;
static Cpx spectra[7][N],work[N],twiddle[N/2];
static float window[W],gcc[21][2*LAG+1],norm_sum;
static int pair_i[21],pair_j[21];
// Assembly drawing: look at LED/numbered face, MIC0 at top; x right,z up.
// y is the selected front half-space. Planar array cannot distinguish +/-y.
static const float xyz[7][3]={
 {0,0,.04f},{.034641016f,0,.02f},{.034641016f,0,-.02f},
 {0,0,-.04f},{-.034641016f,0,-.02f},{-.034641016f,0,.02f},{0,0,0}};
static float coarse_lag[31*25][21];
static void fft(Cpx *a,int inverse){
 for(unsigned i=1,j=0;i<N;i++){
  unsigned b=N>>1;for(;j&b;b>>=1)j^=b;j^=b;
  if(i<j){Cpx t=a[i];a[i]=a[j];a[j]=t;}
 }
 for(int len=2;len<=N;len*=2){
  int half=len/2,step=N/len;
  for(int base=0;base<N;base+=len)for(int j=0;j<half;j++){
   Cpx t=twiddle[j*step];if(inverse)t.i=-t.i;
   Cpx b=a[base+j+half],u=a[base+j];
   Cpx v={b.r*t.r-b.i*t.i,b.r*t.i+b.i*t.r};
   a[base+j]=(Cpx){u.r+v.r,u.i+v.i};a[base+j+half]=(Cpx){u.r-v.r,u.i-v.i};
  }
 }
 if(inverse)for(int i=0;i<N;i++){a[i].r/=N;a[i].i/=N;}
}
static void delays(float az,float el,float *d){
 float a=az*PI/180,e=el*PI/180,ux=cosf(e)*sinf(a),uz=sinf(e);
 for(int p=0;p<21;p++)d[p]=((xyz[pair_j[p]][0]-xyz[pair_i[p]][0])*ux+
 (xyz[pair_j[p]][2]-xyz[pair_i[p]][2])*uz)*AUDIO_FS/343.f;
}
void doa_init(void){
 for(int i=0;i<N/2;i++){twiddle[i].r=cosf(-2*PI*i/N);twiddle[i].i=sinf(-2*PI*i/N);}
 for(int i=0;i<W;i++)window[i]=.5f-.5f*cosf(2*PI*i/(W-1));
 int p=0;for(int i=0;i<7;i++)for(int j=i+1;j<7;j++){pair_i[p]=i;pair_j[p++]=j;}
 int q=0;for(int el=-60;el<=60;el+=5)for(int az=-75;az<=75;az+=5)delays(az,el,coarse_lag[q++]);
}
static float score(const float *d){
 float s=0;
 for(int p=0;p<21;p++){
  float v=d[p]+LAG;int k=(int)floorf(v);float f=v-k;
  if(k<0 || k>=2*LAG)return -1e9f;
  s+=(1-f)*gcc[p][k]+f*gcc[p][k+1];
 }
 return s/(norm_sum+1e-12f);
}
int doa_process(const int32_t *records,float noise_rms,DoaResult *out){
 memset(out,0,sizeof(*out));
 for(int n=0;n<AUDIO_FRAMES;n++)if((uint32_t)records[n*8]!=(uint32_t)n)return -1;
 memset(gcc,0,sizeof(gcc));
 float total_rms=0,tone_total=0;
 for(int f=0;f<3;f++){
  int start=f*512;
  for(int ch=0;ch<7;ch++){
   float mean=0,energy=0;for(int n=0;n<W;n++)mean+=records[(start+n)*8+ch+1]/(float)W;
   for(int n=0;n<N;n++){
    float v=n<W ? records[(start+n)*8+ch+1]-mean : 0;
    if(n<W)energy+=v*v;
    spectra[ch][n]=(Cpx){n<W?v*window[n]:0,0};
   }
   total_rms+=energy/W;fft(spectra[ch],0);
   float band=0,max3=0,prev1=0,prev2=0;
   for(int k=1;k<N/2;k++)if(k*AUDIO_FS/N>=500 && k*AUDIO_FS/N<=6000){
    float v=spectra[ch][k].r*spectra[ch][k].r+spectra[ch][k].i*spectra[ch][k].i;
    band+=v;if(v+prev1+prev2>max3)max3=v+prev1+prev2;prev2=prev1;prev1=v;
   }
   tone_total+=max3/(band+1e-12f);
  }
  for(int p=0;p<21;p++){
   float maxmag=0;
   for(int k=0;k<N;k++){
    float hz=(k<=N/2?k:N-k)*AUDIO_FS/N;
    Cpx a=spectra[pair_i[p]][k],b=spectra[pair_j[p]][k];
    work[k]=(Cpx){0,0};
    if(hz>=500 && hz<=6000){
     work[k]=(Cpx){a.r*b.r+a.i*b.i,a.i*b.r-a.r*b.i};
     float m=hypotf(work[k].r,work[k].i);if(m>maxmag)maxmag=m;
    }
   }
   float floor_mag=fmaxf(maxmag*1e-4f,1e-12f);
   for(int k=0;k<N;k++){
    float m=hypotf(work[k].r,work[k].i);float den=fmaxf(m,floor_mag);
    work[k].r/=den;work[k].i/=den;
   }
   fft(work,1);
   for(int l=-LAG;l<=LAG;l++)gcc[p][l+LAG]+=work[(l+N)%N].r/3.f;
  }
 }
 out->rms=sqrtf(total_rms/21);out->tonality=tone_total/21;
 norm_sum=0;for(int p=0;p<21;p++){float m=0;for(int l=0;l<=2*LAG;l++)m=fmaxf(m,fabsf(gcc[p][l]));norm_sum+=m;}
 float best=-1e9f;int q=0;
 for(int el=-60;el<=60;el+=5)for(int az=-75;az<=75;az+=5){
  float s=score(coarse_lag[q++]);if(s>best){best=s;out->az=az;out->el=el;}
 }
 int az0=(int)out->az,el0=(int)out->el;
 for(int el=el0-5;el<=el0+5;el++)for(int az=az0-5;az<=az0+5;az++){
  if(el< -60||el>60||az< -75||az>75)continue;
  float d[21];delays(az,el,d);float s=score(d);
  if(s>best){best=s;out->az=az;out->el=el;}
 }
 float second=-1e9f;q=0;
 for(int el=-60;el<=60;el+=5)for(int az=-75;az<=75;az+=5){
  float s=score(coarse_lag[q++]);
  if((az-out->az)*(az-out->az)+(el-out->el)*(el-out->el)>=400 && s>second)second=s;
 }
 out->coherence=best;out->margin=best-second;
 // Engineering confidence gates, NOT calibrated CFAR/Pfa guarantees.
 out->valid=out->rms>fmaxf(100.f,noise_rms*2.f) && best>.35f && out->margin>.015f && out->tonality<.6f;
 return 0;
}
