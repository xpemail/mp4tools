#ifndef MP4_BOX2_H
#define MP4_BOX2_H

#ifdef WIN32
typedef unsigned short uint16_t;
typedef unsigned int uint32_t;
typedef int int32_t;
typedef long long int int64_t;
typedef unsigned long long int uint64_t ;
typedef long off_t;
#else
#include <stdint.h>
#endif
#include <stdarg.h>
#ifdef WIN32
#include <winsock2.h>
#else
#include <arpa/inet.h>
#endif
#include <vector>
#include <string>
#include <string.h>
#include "mp4tools.h"

class mp4_sample 
{
public:
	mp4_sample() {
		pts = 0;
		delta = 0;
		chunk = 0;
		size = 0;
		offset = 0;
		keyframe = 0;
		trak = 0;
		sync = 0;
		leader = 0;
		cto = 0;
		file_index = 0;
		old_offset = 0;
		timecode = 0;
		vide = 0;
	}
public:
	unsigned int pts;
	int delta;
	int chunk;
	int size;
	unsigned int offset;
	int keyframe;
	int trak;
	int sync;
	int leader;
	int cto;
	int file_index;
	unsigned int old_offset;
	uint64_t timecode;
	int vide;
public:
	void dump();
};

class mp4_box;
class mp4_box_factory
{
public:
	virtual mp4_box* create_mp4_box(const char* box_type);
};

class mp4_box
{
public:
	mp4_box(const char* box_type);
	virtual ~mp4_box();
public:
	void set_container(bool is_container) {
		is_container_ = is_container;
	} 
	void set_factory(mp4_box_factory* factory) {
		factory_ = factory;
	}
	int boxize(std::string& data);
	int total_size();
	void add_child(mp4_box* child);
	mp4_box* get(const char* box_type);
	void dump_box_type(int level);
	void dump_dots_box_type(char* path);
	const char* box_type() {
		return box_type_;
	}
	std::vector<mp4_box*>& children() {
		return children_;
	}

	void change_content(int pos,const char* value,size_t size)
	{
		memcpy((char*)content_.data() + pos,value,size);
	}

	void set_content(const char* value,size_t size)
	{
		this->content_.assign((const char*)value,size);
	}
public:
	virtual void pack_content();
	virtual int unpack_content(const char* data,int length,int max_children = -1);
	virtual int content_size();
	virtual void pack_preface(std::string& content) {
		
	}
	virtual int unpack_preface(const char* data,int length) 
	{
		return 0;
	}
private:
	char box_type_[8];
	std::string content_;
	bool is_container_;
	std::vector<mp4_box*> children_;
	mp4_box_factory* factory_;
};

class mdat_box: public mp4_box
{
public:
	mdat_box():mp4_box("mdat") {
	}
	virtual ~mdat_box() {
	}
};

class trak_box;
class moov_box: public mp4_box
{
public:
	moov_box():mp4_box("moov") {
	}
	virtual ~moov_box() {
	}
public:
	int seek(std::vector<mp4_sample*>& result,int start,int end);
	int get_samples(std::vector<mp4_sample*>& samples);
	void set_samples(std::vector<mp4_sample*>& samples);
	trak_box* get_trak(unsigned int handler_type);
private:
	std::vector<mp4_sample*> samples_;
};


//time to sample
class stts_box: public mp4_box
{
public:
	stts_box():mp4_box("stts") {
	}
	virtual ~stts_box() {
	}
	virtual int content_size();
	virtual void pack_content();
	virtual int unpack_content(const char* data,int length,int max_children = -1);
public:
	std::vector<std::pair<int,int> > entries_;
private:
	unsigned int version_flags_;
};

//sample to chunk
class stsc_box: public mp4_box
{
public:
	stsc_box():mp4_box("stsc") {
	}
	virtual ~stsc_box() {
	}
	virtual int content_size();
	virtual void pack_content();
	virtual int unpack_content(const char* data,int length,int max_children = -1);
public:
	std::vector<std::pair<int,int> > entries_;
private:
	unsigned int version_flags_;
};

//sample size
class stsz_box: public mp4_box
{
public:
	stsz_box():mp4_box("stsz") {
	}
	virtual ~stsz_box() {
	}
	virtual int content_size();
	virtual void pack_content();
	virtual int unpack_content(const char* data,int length,int max_children = -1);
public:
	std::vector<int> entries_;
private:
	unsigned int version_flags_;
	int sample_size_;
};

//chunk offset
class stco_box: public mp4_box
{
public:
	stco_box():mp4_box("stco") {
		bit64_ = false;
	}
	virtual ~stco_box() {
	}
	virtual int content_size();
	virtual void pack_content();
	virtual int unpack_content(const char* data,int length,int max_children = -1);
public:
	std::vector<int> entries_;
private:
	unsigned int version_flags_;
	bool bit64_;
};

//sync sample
class stss_box: public mp4_box
{
public:
	stss_box():mp4_box("stss") {
	}
	virtual ~stss_box() {
	}
	virtual int content_size();
	virtual void pack_content();
	virtual int unpack_content(const char* data,int length,int max_children = -1);
public:
	std::vector<int> entries_;
private:
	unsigned int version_flags_;
};

//composition time offset table
class ctts_box: public mp4_box
{
public:
	ctts_box():mp4_box("ctts") {
	}
	virtual ~ctts_box() {
	}
	virtual int content_size();
	virtual void pack_content();
	virtual int unpack_content(const char* data,int length,int max_children = -1);
public:
	std::vector<std::pair<int,int> > entries_;
private:
	unsigned int version_flags_;
};

class mvhd_box: public mp4_box
{
public:
	mvhd_box():mp4_box("mvhd") {
	}
	virtual ~mvhd_box() {
	}
	virtual void pack_content();
	virtual int unpack_content(const char* data,int length,int max_children = -1);
public:
	unsigned int timescale_;
	uint64_t duration_;
private:
	unsigned char version_;
};

class tkhd_box: public mp4_box
{
public:
	tkhd_box():mp4_box("tkhd") {
	}
	virtual ~tkhd_box() {
	}
	virtual void pack_content();
	virtual int unpack_content(const char* data,int length,int max_children = -1);
public:
	uint64_t duration_;
private:
	unsigned char version_;
};

class trak_box: public mp4_box
{
public:
	trak_box():mp4_box("trak") {
	}
	virtual ~trak_box() {
	}
public:
	int get_samples(std::vector<mp4_sample*>& samples);
	void set_samples(std::vector<mp4_sample*>& samples,mvhd_box* mvhd);
private:
	std::vector<mp4_sample*> samples_;
};

class mdhd_box: public mp4_box
{
public:
	mdhd_box():mp4_box("mdhd") {
	}
	virtual ~mdhd_box() {
	}
	virtual void pack_content();
	virtual int unpack_content(const char* data,int length,int max_children = -1);
public:
	unsigned int timescale_;
	uint64_t duration_;
private:
	unsigned char version_;
};

class hdlr_box: public mp4_box
{
public:
	hdlr_box():mp4_box("hdlr") {
	}
	virtual ~hdlr_box() {
	}
	virtual int unpack_content(const char* data,int length,int max_children = -1);
public:
	unsigned int handler_type_;
};

class stsd_box: public mp4_box
{
public:
	stsd_box():mp4_box("stsd") {
	}
	virtual ~stsd_box() {
	}
	virtual void pack_preface(std::string& content) {
		content.append(preface_);
	}
	virtual int unpack_preface(const char* data,int length) 
	{
		preface_.assign((const char*)data,8);
		return 8;
	}
public:
	std::string preface_;
};

class avc1_box: public mp4_box
{
public:
	avc1_box():mp4_box("avc1") {
	}
	virtual ~avc1_box() {
	}
	virtual void pack_preface(std::string& content) {
		content.append(preface_);
	}
	virtual int unpack_preface(const char* data,int length) 
	{
		int pos = 0;
		pos += 6;
		pos += 2;
		pos += (16 + 16 + 32 * 3) / 8;
		pos += 12;
		pos += 4;
		pos += 38;
		preface_.assign((const char*)data,pos);
		return pos;
	}
public:
	std::string preface_;
};

class avcC_box: public mp4_box
{
public:
	avcC_box():mp4_box("avcC") {
	}
	virtual ~avcC_box() {
	}
public:
	virtual int unpack_content(const char* data,int length,int max_children);
public:
	std::string SequenceParameterSet;
	std::string PictureParameterSet;
};

class mp4a_box: public mp4_box
{
public:
	mp4a_box():mp4_box("mp4a") {
	}
	virtual ~mp4a_box() {
	}
	virtual void pack_preface(std::string& content) {
		content.append(preface_);
	}
	virtual int unpack_preface(const char* data,int length) 
	{
		int pos = 0;
		pos += 6;
		pos += 2;
		pos += 8;
		pos += 6;
		pos += 2;
		pos += 2;
		pos += 2;
		preface_.assign((const char*)data,pos);
		return pos;
	}
public:
	std::string preface_;
};

class esds_box: public mp4_box
{
public:
	esds_box():mp4_box("esds") {
	}
	virtual ~esds_box() {
	}
public:
	virtual int unpack_content(const char* data,int length,int max_children);
public:
	std::string AudioSpecificConfig;
};


#endif
