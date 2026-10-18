#pragma once
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <iostream>
#include <map>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>
using real_t = float;
using String = std::string;
#define ERR_FAIL_COND(c) do { if (c) throw std::runtime_error(#c); } while (0)
#define ERR_FAIL_NULL(c) ERR_FAIL_COND(!(c))
#define ERR_FAIL_COND_V(c, v) do { if (c) throw std::runtime_error(#c); } while (0)
#define ERR_PRINT(s) do { throw std::runtime_error(s); } while (0)
#define MAX(a,b) std::max((a),(b))
#define MIN(a,b) std::min((a),(b))
#define CLAMP(v,a,b) std::clamp((v),(a),(b))
struct Vec2 {
 union { real_t x; real_t width; }; union { real_t y; real_t height; };
 Vec2(real_t a=0, real_t b=0):x(a),y(b){}
 Vec2 operator-(Vec2 b)const{return{x-b.x,y-b.y};}
 Vec2 operator+(Vec2 b)const{return{x+b.x,y+b.y};}
 Vec2 operator/(real_t b)const{return{x/b,y/b};}
 Vec2 &operator/=(Vec2 b){x/=b.x;y/=b.y;return *this;}
 Vec2 floor()const{return{std::floor(x),std::floor(y)};}
 bool operator==(Vec2 b)const{return x==b.x&&y==b.y;}
};
using Size2=Vec2; using Size2i=Vec2; using Point2i=Vec2;
struct Rect2 { Vec2 position,size; Rect2(real_t x=0,real_t y=0,real_t w=0,real_t h=0):position(x,y),size(w,h){} };
using Rect2i=Rect2;
struct Color {float r=.1f,g=.2f,b=.3f,a=.4f;};
template<class T> struct Vector {
 std::vector<T> data;
 struct Writer { Vector *owner; T &operator[](size_t i){return owner->data.at(i);} } write{this};
 Vector()=default;
 Vector(const Vector&o):data(o.data),write{this}{}
 Vector&operator=(const Vector&o){data=o.data;return *this;}
 void resize(size_t n){data.resize(n);}
 size_t size()const{return data.size();}
 bool is_empty()const{return data.empty();}
 void push_back(const T&t){data.push_back(t);}
 T&operator[](size_t i){return data.at(i);}
 const T&operator[](size_t i)const{return data.at(i);}
 T *ptrw(){return data.data();} const T *ptr()const{return data.data();}
 auto begin()const{return data.begin();}auto end()const{return data.end();}
};
template<class T>struct Ref {
 std::shared_ptr<T> value;
 Ref()=default;explicit Ref(std::shared_ptr<T>v):value(v){}
 bool is_null()const{return !value;}bool is_valid()const{return bool(value);}
 T*operator->()const{return value.get();}
 bool operator==(const Ref&b)const{return value==b.value;}
 void unref(){value.reset();}
};
struct Image {
 enum Format{FORMAT_L8,FORMAT_LA8,FORMAT_RGB8,FORMAT_RGBA8,FORMAT_RGBAF,FORMAT_RGTC_R,FORMAT_RGTC_RG,FORMAT_MAX};
 int width=0,height=0;Format format=FORMAT_RGBA8;bool mipmaps=false;Vector<uint8_t> bytes;
 static int channels(Format f){return f==FORMAT_L8?1:f==FORMAT_LA8?2:f==FORMAT_RGB8?3:4;}
 static Ref<Image>create_empty(int w,int h,bool m,Format f){auto a=std::make_shared<Image>();a->width=w;a->height=h;a->format=f;a->mipmaps=m;a->bytes.resize(size_t(w)*h*channels(f));return Ref<Image>(a);}
 static Ref<Image>create_from_data(int w,int h,bool m,Format f,const Vector<uint8_t>&b){auto a=create_empty(w,h,m,f);a->bytes=b;return a;}
 int get_width()const{return width;}int get_height()const{return height;}
 Vec2 get_size()const{return{real_t(width),real_t(height)};}
 Format get_format()const{return format;}bool has_mipmaps()const{return mipmaps;}
 bool is_empty()const{return width==0||height==0;}bool is_compressed()const{return false;}
 int get_mipmap_count()const{return 0;}Vector<uint8_t>get_data()const{return bytes;}
 int64_t get_data_size()const{return bytes.size();}
 int64_t get_image_data_size(int w,int h,Format f,int)const{return int64_t(w)*h*channels(f);}
 void get_mipmap_offset_and_size(int i,int64_t&ofs,int64_t&size)const{if(i)throw std::runtime_error("unexpected mip");ofs=0;size=bytes.size();}
 Ref<Image>duplicate()const{return Ref<Image>(std::make_shared<Image>(*this));}
 void resize_to_po2(bool){throw std::runtime_error("unexpected resize");}
 void blit_rect(const Ref<Image>&from,Rect2i rect,Point2i dst){int c=channels(format);for(int y=0;y<int(rect.size.y);++y){size_t si=(size_t(int(rect.position.y)+y)*from->width+int(rect.position.x))*c;size_t di=(size_t(int(dst.y)+y)*width+int(dst.x))*c;std::memcpy(bytes.ptrw()+di,from->bytes.ptr()+si,size_t(int(rect.size.x))*c);}}
};
namespace RSE {
 enum SplashStretchMode {SPLASH_STRETCH_MODE_DISABLED,SPLASH_STRETCH_MODE_KEEP,SPLASH_STRETCH_MODE_KEEP_WIDTH,SPLASH_STRETCH_MODE_KEEP_HEIGHT,SPLASH_STRETCH_MODE_COVER,SPLASH_STRETCH_MODE_IGNORE};
 enum {CANVAS_ITEM_TEXTURE_FILTER_NEAREST=1,CANVAS_ITEM_TEXTURE_FILTER_LINEAR,CANVAS_ITEM_TEXTURE_FILTER_NEAREST_WITH_MIPMAPS,CANVAS_ITEM_TEXTURE_REPEAT_ENABLED};
}
namespace DisplayServerEnums {enum{MAIN_WINDOW_ID};}
struct DisplayServer {static DisplayServer*get_singleton(){static DisplayServer s;return &s;}Size2i window_get_size(){return{901,617};}};
struct OS {static OS*get_singleton(){static OS s;return &s;}bool is_layered_allowed(){return false;}};
struct RID {int id=0;RID(int v=0):id(v){};};
