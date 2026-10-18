#include "gles_recording.h"
#include "extracted_native.inc"
void check(bool value,const std::string&message){if(!value)throw std::runtime_error(message);}
bool same(Rect2 a,Rect2 b){return a.position==b.position&&a.size==b.size;}
Ref<Image>fixture(Image::Format format,int width=2360,int height=1640){
 auto image=Image::create_empty(width,height,false,format);
 auto*p=image->bytes.ptrw();for(size_t i=0;i<image->bytes.size();++i)p[i]=uint8_t((i*37+i/2360)%251);
 return image;
}
void boot_case(Image::Format format){
 recording.reset();TextureStorage storage;CopyEffects effects;RasterizerGLES3 renderer{&storage,&effects};
 auto image=fixture(format);renderer.set_boot_image_with_stretch(image,Color(),RSE::SPLASH_STRETCH_MODE_KEEP,true);
 check(recording.allocations==1&&recording.textures.size()==1,"expected ONE full-size boot GPU texture; sliced allocations change normalized sampling");
 const auto&tex=recording.textures.begin()->second;
 check(tex.width==2360&&tex.height==1640,"boot GPU allocation must retain original image dimensions");
 check(recording.draws.size()==1,"boot must retain original single full-image quad");
 check(same(recording.draws[0].source,Rect2(0,0,1,1)),"boot must retain original 0..1 source UVs");
 Rect2 expected=RenderingServerTypes::get_splash_stretched_screen_rect(image->get_size(),Vec2(901,617),RSE::SPLASH_STRETCH_MODE_KEEP);
 expected.position.y=617-expected.position.y;expected.size.y=-expected.size.y;expected.position/=Vec2(901,617);expected.size/=Vec2(901,617);
 check(same(recording.draws[0].destination,expected),"original full-image destination geometry changed");
 check(recording.clears==1&&recording.presents==1,"boot must clear and present exactly once");
 check(tex.freed,"boot texture cleanup missing");
 check(tex.bytes==image->bytes.data,"assembled native GPU bytes differ from original source, including hidden alpha");
 check(recording.uploads.size()==4,"large native boot must use four bounded owned-row uploads");
 int row=0;for(const auto&u:recording.uploads){
  check(u.id==recording.draws[0].id,"data uploaded to a texture other than the full-image draw source");
  check(u.subimage,"boot data must use subimage transfers after empty allocation");
  check(u.x==0&&u.y==row&&u.width==2360&&u.height==410,"boot transfers must cover balanced original owned rows without gutters");
  check(uint64_t(u.width)*u.height*4<=4*1024*1024,"conservative RGBA native transfer exceeds 4 MiB");row+=u.height;
 }
 check(row==1640,"boot transfer rows do not exactly cover original image");
 std::cout<<"PASS boot actual compositor/initializer/upload body format="<<int(format)<<" uploads=4 draws=1 bytes_exact=true\n";
}
void public_api_control(){
 recording.reset();TextureStorage storage;auto image=fixture(Image::FORMAT_RGBA8);RID id=storage.texture_allocate();storage.texture_2d_initialize(id,image);
 check(recording.allocations==1&&recording.uploads.size()==1,"ordinary texture initializer was rerouted into boot-only banding");
 check(!recording.uploads[0].subimage&&recording.uploads[0].bytes>4*1024*1024,"ordinary API oversized control changed");
 check(recording.textures.begin()->second.bytes==image->bytes.data,"ordinary API pixels changed");
 std::cout<<"PASS unchanged ordinary API oversized control\n";
}
int main(){try{
 public_api_control();
 for(auto format:{Image::FORMAT_RGBA8,Image::FORMAT_RGB8,Image::FORMAT_L8,Image::FORMAT_LA8})boot_case(format);
 std::cout<<"PASS GLES source-bound native boot regression\n";return 0;
 }catch(const std::exception&e){std::cerr<<"FAIL GLES source-bound native boot regression: "<<e.what()<<"\n";return 1;}}
