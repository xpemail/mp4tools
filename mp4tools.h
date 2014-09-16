#ifndef MP4TOOLS_H
#define MP4TOOLS_H

#ifdef __cplusplus
extern "C" {
#endif

int merge_mp4_files(int n,const char *srcfile[],int start[],int end[],const char* destfile);
int tsfile_from_mp4(const char *srcfile,int start,int end,const char* destfile,int pts0);
int mp4_stss_size(const char *srcfile);

#ifdef __cplusplus
}
#endif

#endif
