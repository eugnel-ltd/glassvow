#pragma once
#include "gles_types.h"
using GLuint=unsigned;using GLenum=unsigned;using GLsizei=int;using GLint=int;
constexpr GLenum GL_TEXTURE_2D=1, GL_TEXTURE_3D=2, GL_TEXTURE_2D_ARRAY=3, GL_TEXTURE_CUBE_MAP=4;
constexpr GLenum GL_RED=5, GL_RG=6, GL_RGB=7, GL_RGBA=8, GL_UNSIGNED_BYTE=9;
constexpr GLenum GL_TEXTURE0=10, GL_FRAMEBUFFER=11, GL_BLEND=12, GL_SRC_ALPHA=13;
constexpr GLenum GL_ONE_MINUS_SRC_ALPHA=14, GL_ONE=15, GL_COLOR_BUFFER_BIT=16;
constexpr GLenum GL_FALSE=0, GL_UNPACK_ALIGNMENT=17;
struct GLTexture {int width=0,height=0,channels=0;bool freed=false;std::vector<uint8_t> bytes;};
struct GLUpload {GLuint id;int x,y,width,height;size_t bytes;bool subimage;};
struct GLDraw {GLuint id;Rect2 destination,source;};
struct Recording {
 GLuint next=1,bound=0;int allocations=0,clears=0,presents=0;
 std::map<GLuint,GLTexture> textures;std::vector<GLUpload> uploads;std::vector<GLDraw> draws;
 Rect2 next_destination,next_source=Rect2(0,0,1,1);int shader_variant=0;
 void reset(){*this=Recording();}
};
inline Recording recording;
inline int gl_channels(GLenum format){return format==GL_RED?1:format==GL_RG?2:format==GL_RGB?3:4;}
inline void glGenTextures(int n,GLuint*ids){for(int i=0;i<n;++i){ids[i]=recording.next++;recording.textures.emplace(ids[i],GLTexture());}}
inline void glActiveTexture(GLenum){}
inline void glBindTexture(GLenum,GLuint id){if(id&&!recording.textures.count(id))throw std::runtime_error("unknown bound texture");recording.bound=id;}
inline void glTexImage2D(GLenum,int level,GLenum,int width,int height,int,GLenum format,GLenum,const void*data){
 if(level||!recording.bound)throw std::runtime_error("unexpected image allocation");
 auto&t=recording.textures.at(recording.bound);t.width=width;t.height=height;t.channels=gl_channels(format);t.bytes.resize(size_t(width)*height*t.channels);++recording.allocations;
 if(data){std::memcpy(t.bytes.data(),data,t.bytes.size());recording.uploads.push_back({recording.bound,0,0,width,height,t.bytes.size(),false});}
}
inline void glTexSubImage2D(GLenum,int level,int x,int y,int width,int height,GLenum format,GLenum,const void*data){
 if(level||!recording.bound||!data)throw std::runtime_error("invalid subimage upload");
 auto&t=recording.textures.at(recording.bound);int c=gl_channels(format);
 if(c!=t.channels||x<0||y<0||x+width>t.width||y+height>t.height)throw std::runtime_error("subimage bounds/format");
 for(int row=0;row<height;++row)std::memcpy(t.bytes.data()+(size_t(y+row)*t.width+x)*c,static_cast<const uint8_t*>(data)+size_t(row)*width*c,size_t(width)*c);
 recording.uploads.push_back({recording.bound,x,y,width,height,size_t(width)*height*c,true});
}
inline void glPixelStorei(GLenum,int){}
inline void glBindFramebuffer(GLenum,GLuint){}
inline void glViewport(int,int,int,int){}
inline void glEnable(GLenum){}
inline void glBlendFuncSeparate(GLenum,GLenum,GLenum,GLenum){}
inline void glDepthMask(GLenum){}
inline void glClearColor(float,float,float,float){}
inline void glClear(GLenum){++recording.clears;}
template<class...T>void glTexImage3D(T...){throw std::runtime_error("unexpected 3d image");}
template<class...T>void glTexSubImage3D(T...){throw std::runtime_error("unexpected 3d upload");}
template<class...T>void glCompressedTexImage2D(T...){throw std::runtime_error("unexpected compressed image");}
template<class...T>void glCompressedTexImage3D(T...){throw std::runtime_error("unexpected compressed image");}
template<class...T>void glCompressedTexSubImage3D(T...){throw std::runtime_error("unexpected compressed upload");}
struct RasterizerUtilGLES3 {static bool is_gles_over_gl(){return true;}};
inline GLenum _cube_side_enum[6]={};
namespace GLES3 {
struct Texture {
 enum {TYPE_2D,TYPE_LAYERED};
 int width=0,height=0,alloc_width=0,alloc_height=0,mipmaps=0,type=0,layers=0;
 Image::Format format=Image::FORMAT_RGBA8,real_format=Image::FORMAT_RGBA8;
 GLenum target=GL_TEXTURE_2D,gl_format_cache=0,gl_internal_format_cache=0,gl_type_cache=0;
 bool compressed=false,active=false,is_render_target=false,resize_to_po2=false,boot_image_upload=false;
 int total_data_size=0,stored_cube_sides=0;GLuint tex_id=0;String path;
 void gl_set_filter(int){}void gl_set_repeat(int){}
};
struct TextureOwner {
 std::map<int,Texture> textures;
 void initialize_rid(RID id,const Texture&t){textures[id.id]=t;}
 Texture*get_or_null(RID id){auto it=textures.find(id.id);return it==textures.end()?nullptr:&it->second;}
};
struct Utilities {static Utilities*get_singleton(){static Utilities u;return &u;}void texture_allocated_data(GLuint,int64_t,const char*){}};
struct TextureStorage {
 static constexpr GLuint system_fbo=0;TextureOwner texture_owner;int next_rid=1;
 RID texture_allocate(){return RID(next_rid++);}
 void texture_free(RID rid){auto*t=texture_owner.get_or_null(rid);if(!t)throw std::runtime_error("free unknown texture");auto&r=recording.textures.at(t->tex_id);if(r.freed)throw std::runtime_error("double texture free");r.freed=true;}
 Texture*get_texture(RID rid){return texture_owner.get_or_null(rid);}
 void texture_2d_initialize(RID,const Ref<Image>&);
 void texture_2d_initialize_boot_image(RID,const Ref<Image>&);
 void _texture_2d_initialize(RID,const Ref<Image>&,bool);
 void texture_set_data(RID,const Ref<Image>&,int layer=0);
 void _texture_set_data(RID,const Ref<Image>&,int,bool);
 void _texture_set_swizzle(Texture*,Image::Format){}
 Ref<Image>_get_gl_image_and_format(const Ref<Image>&img,Image::Format f,Image::Format&real,GLenum&format,GLenum&internal,GLenum&type,bool&compressed,bool){real=f;compressed=false;format=f==Image::FORMAT_L8?GL_RED:f==Image::FORMAT_LA8?GL_RG:f==Image::FORMAT_RGB8?GL_RGB:GL_RGBA;internal=format;type=GL_UNSIGNED_BYTE;return img;}
};
struct CopyShaderGLES3 {enum {MODE_COPY_SECTION=1,MODE_COPY_SECTION_SOURCE,COPY_SECTION,SOURCE_SECTION,CONVERT_LINEAR_TO_SRGB=1};};
struct RecordingShader {
 bool version_bind_shader(int,int variant,uint64_t=0){recording.shader_variant=variant;recording.next_source=Rect2(0,0,1,1);return true;}
 void version_set_uniform(int name,float x,float y,float w,float h,int,int,uint64_t=0){if(name==CopyShaderGLES3::COPY_SECTION)recording.next_destination=Rect2(x,y,w,h);else if(name==CopyShaderGLES3::SOURCE_SECTION)recording.next_source=Rect2(x,y,w,h);else throw std::runtime_error("unknown copy uniform");}
};
struct CopyEffects {
 struct {RecordingShader shader;int shader_version=1;}copy;
 void copy_to_rect(const Rect2&,bool p_linear_to_srgb=false);
 void copy_to_rect_from_rect(const Rect2&,const Rect2&);
 void draw_screen_quad(){recording.draws.push_back({recording.bound,recording.next_destination,recording.next_source});}
};
}
using GLES3::TextureStorage;using GLES3::CopyEffects;
struct RasterizerGLES3 {
 TextureStorage *texture_storage;CopyEffects *copy_effects;
 void set_boot_image_with_stretch(const Ref<Image>&,const Color&,RSE::SplashStretchMode,bool);
 void gl_end_frame(bool){++recording.presents;}
};
