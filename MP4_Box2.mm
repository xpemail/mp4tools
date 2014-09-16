#include <stdio.h>
#include <stdlib.h>
#include <algorithm>
#include <iterator>
#include "MP4_Box2.h"
//#include "TS_Packetizer.h"

mp4_box* parse_mp4_file(const char* filename,int stsd = 0);

static unsigned int read_8(unsigned char const* buffer)
{
	return buffer[0];
}

static unsigned char* write_8(unsigned char* buffer, unsigned char v)
{
	buffer[0] = v;

	return buffer + 1;
}

static void swrite_8(std::string& str,unsigned char v) 
{
	str.append(1,(char)v);
}

static unsigned short read_16(unsigned char const* buffer)
{
	return (buffer[0] << 8) | (buffer[1] << 0);
}

static unsigned char* write_16(unsigned char* buffer, unsigned int v)
{
	buffer[0] = (unsigned char)(v >> 8);
	buffer[1] = (unsigned char)(v >> 0);

	return buffer + 2;
}

static void swrite_16(std::string& str,unsigned int v) 
{
	char buffer[2];
	buffer[0] = (unsigned char)(v >> 8);
	buffer[1] = (unsigned char)(v >> 0);
	str.append((const char*)buffer,2);
}

static unsigned int read_24(unsigned char const* buffer)
{
	return (buffer[0] << 16) | (buffer[1] << 8) | (buffer[2] << 0);
}

static unsigned char* write_24(unsigned char* buffer, unsigned int v)
{
	buffer[0] = (unsigned char)(v >> 16);
	buffer[1] = (unsigned char)(v >> 8);
	buffer[2] = (unsigned char)(v >> 0);

	return buffer + 3;
}

static void swrite_24(std::string& str, unsigned int v)
{
	char buffer[4];
	buffer[0] = (unsigned char)(v >> 16);
	buffer[1] = (unsigned char)(v >> 8);
	buffer[2] = (unsigned char)(v >> 0);

	str.append((const char*)buffer,3);
}

static uint32_t read_32(unsigned char const* buffer)
{
	return (buffer[0] << 24) | (buffer[1] << 16) | (buffer[2] << 8) | (buffer[3] << 0);
}

static unsigned char* write_32(unsigned char* buffer, uint32_t v)
{
	buffer[0] = (unsigned char)(v >> 24);
	buffer[1] = (unsigned char)(v >> 16);
	buffer[2] = (unsigned char)(v >> 8);
	buffer[3] = (unsigned char)(v >> 0);

	return buffer + 4;
}

static void swrite_32(std::string& str, uint32_t v)
{
	unsigned char buffer[4];
	buffer[0] = (unsigned char)(v >> 24);
	buffer[1] = (unsigned char)(v >> 16);
	buffer[2] = (unsigned char)(v >> 8);
	buffer[3] = (unsigned char)(v >> 0);

	str.append((const char*)buffer,4);
}

static uint64_t read_64(unsigned char const* buffer)
{
	return ((uint64_t)(read_32(buffer)) << 32) + read_32(buffer + 4);
}


static unsigned char* write_64(unsigned char* buffer, uint64_t v)
{
	write_32(buffer + 0, (uint32_t)(v >> 32));
	write_32(buffer + 4, (uint32_t)(v >> 0));

	return buffer + 8;
}

static void swrite_64(std::string& str, uint64_t v)
{
	unsigned char buffer[8];

	write_32(buffer + 0, (uint32_t)(v >> 32));
	write_32(buffer + 4, (uint32_t)(v >> 0));

	str.append((const char*)buffer,8);
}

int unique_counter(std::vector<mp4_sample*>& input,int offset,std::vector<std::pair<int,int> > & result)
{
	if (input.size() == 0) {
		return result.size();
	}
	result.push_back(std::make_pair(1,*((int*)((char*)input[0] + offset))));
	for (int i = 1; i < input.size();i++) {
		int e = *((int*)((char*)input[i] + offset));
		if (result[result.size() - 1].second != e) {
			result.push_back(std::make_pair(1,e));
		} else {
			result[result.size() - 1].first += 1;
		}
	}
	return result.size();
}

bool mp4_sample_offset_cmp(mp4_sample* s1,mp4_sample* s2)
{
	if (s1->offset < s2->offset) {
		return true;
	} 
	return false;
}

bool mp4_sample_timecode_cmp(mp4_sample* s1,mp4_sample* s2) {
	if (s1->timecode < s2->timecode) {
		return true;
	} 
	return false;
}

void mp4_sample::dump()
{
	printf("(%d,%d,%d,%d,%d,0x%08x,%d,%d) 0x%08x %s\n",trak,chunk,pts,delta,cto,offset,size,sync,offset + size, keyframe?"*":"");

}

mp4_box* mp4_box_factory::create_mp4_box(const char* box_type)
{
	mp4_box* box = NULL;
	if (strcmp(box_type,"mdat") == 0) {
		box = new mdat_box();
	} else if (strcmp(box_type,"moov") == 0) {
		box = new moov_box();
	} else if (strcmp(box_type,"stts") == 0) {
		box = new stts_box();
	} else if (strcmp(box_type,"stsc") == 0) {
		box = new stsc_box();
	} else if (strcmp(box_type,"stsz") == 0) {
		box = new stsz_box();
	} else if (strcmp(box_type,"stco") == 0) {
		box = new stco_box();
	} else if (strcmp(box_type,"stss") == 0) {
		box = new stss_box();
	} else if (strcmp(box_type,"ctts") == 0) {
		box = new ctts_box();
	} else if (strcmp(box_type,"mvhd") == 0) {
		box = new mvhd_box();
	} else if (strcmp(box_type,"tkhd") == 0) {
		box = new tkhd_box();
	} else if (strcmp(box_type,"trak") == 0) {
		box = new trak_box();
	} else if (strcmp(box_type,"mdhd") == 0) {
		box = new mdhd_box();
	} else if (strcmp(box_type,"hdlr") == 0) {
		box = new hdlr_box();
	}  else {
		box = new mp4_box(box_type);
	}
	bool is_container = false;
	static const char* containers_[] = {"","moov","udta","trak","edts","mdia","minf","dinf","stbl"};
	for (int i = 0; i < sizeof(containers_) / sizeof (containers_[0]);i++) {
		if (strcmp(box_type,containers_[i]) == 0) {
			is_container = true;
			break;
		}
	}
	box->set_factory(this);
	box->set_container(is_container);
	return box;
}

class stsd_mp4_box_factory: public mp4_box_factory
{
public: 
	virtual mp4_box* create_mp4_box(const char* box_type);
};

mp4_box* stsd_mp4_box_factory::create_mp4_box(const char* box_type)
{
	mp4_box* box = NULL;
	if (strcmp(box_type,"mdat") == 0) {
		box = new mdat_box();
	} else if (strcmp(box_type,"moov") == 0) {
		box = new moov_box();
	} else if (strcmp(box_type,"stts") == 0) {
		box = new stts_box();
	} else if (strcmp(box_type,"stsc") == 0) {
		box = new stsc_box();
	} else if (strcmp(box_type,"stsz") == 0) {
		box = new stsz_box();
	} else if (strcmp(box_type,"stco") == 0) {
		box = new stco_box();
	} else if (strcmp(box_type,"stss") == 0) {
		box = new stss_box();
	} else if (strcmp(box_type,"ctts") == 0) {
		box = new ctts_box();
	} else if (strcmp(box_type,"mvhd") == 0) {
		box = new mvhd_box();
	} else if (strcmp(box_type,"tkhd") == 0) {
		box = new tkhd_box();
	} else if (strcmp(box_type,"trak") == 0) {
		box = new trak_box();
	} else if (strcmp(box_type,"mdhd") == 0) {
		box = new mdhd_box();
	} else if (strcmp(box_type,"hdlr") == 0) {
		box = new hdlr_box();
	} else if (strcmp(box_type,"stsd") == 0) {
		box = new stsd_box();
	} else if (strcmp(box_type,"mp4a") == 0) {
		box = new mp4a_box();
	} else if (strcmp(box_type,"esds") == 0) {
		box = new esds_box();
	} else if (strcmp(box_type,"avc1") == 0) {
		box = new avc1_box();
	} else if (strcmp(box_type,"avcC") == 0) {
		box = new avcC_box();
	} else {
		box = new mp4_box(box_type);
	}
	bool is_container = false;
	static const char* containers_[] = {"","moov","udta","trak","edts","mdia","minf","dinf","stbl","stsd","avc1","mp4a"};
	for (int i = 0; i < sizeof(containers_) / sizeof (containers_[0]);i++) {
		if (strcmp(box_type,containers_[i]) == 0) {
			is_container = true;
			break;
		}
	}
	box->set_factory(this);
	box->set_container(is_container);
	return box;
}

mp4_box* parse_mp4_file(const char* filename,int stsd)
{
	unsigned int fsize = 0;
	FILE* h = fopen(filename, "rb");
	if (h == NULL) {
		return NULL;
	}
	fseek(h,0,SEEK_END);
	fsize = ftell(h);
	fseek(h,0,SEEK_SET);
	printf("filename = %s,fsize = %d\n",filename,fsize);
	unsigned int pos = 0;
	mp4_box_factory* factory = NULL;
	if (stsd) {
		factory = new stsd_mp4_box_factory();
	} else {
		factory = new mp4_box_factory();
	}
	mp4_box* root = factory->create_mp4_box("");
	int has_moov = 0;
	while (pos < fsize) {
		fseek(h,pos,SEEK_SET);
		printf("file position: 0x%08x (%d)\n",ftell(h),ftell(h));
		uint64_t total_size = 0;
		char box_type[8] = {0};
		unsigned char buffer[8];
		fread(buffer,8,1,h);
		total_size = read_32(buffer);
		memcpy(box_type,buffer + 4,4);
		box_type[4] = '\0';
		printf("box_type = %s,total_size = %d\n",box_type,total_size);
		int used = 8;
		if (total_size == 1) {
			fread(buffer,8,1,h);
			total_size = read_64(buffer);
			used += 8;
		}
		if (strcmp(box_type,"mdat") != 0) {
			mp4_box* box = factory->create_mp4_box(box_type);
			root->add_child(box);
			char* p = new char[total_size - used];
			fread(p,1,total_size - used,h);
			box->unpack_content(p,total_size - used);
			delete p;
			if (strcmp(box_type,"moov") == 0) {
				has_moov = 1;
			}
		} else if (has_moov == 1) {
			break;
		}
		pos += total_size;
	}
	fclose(h);
	delete factory;
	return root;
}

int mp4_stss_size(const char *srcfile)
{
	mp4_box* my_root = parse_mp4_file(srcfile,0);
	if (my_root == NULL) {
		return 0;
	}
	moov_box* moov = (moov_box*)my_root->get("moov");
	trak_box* vide = moov->get_trak(0x76696465);
	stss_box* stss = (stss_box*)vide->get("mdia")->get("minf")->get("stbl")->get("stss");
	int size = stss->entries_.size();
	delete my_root;
	return size;
}

int tsfile_from_mp4(const char *srcfile,int start,int end,const char* destfile,int pts0)
{
    /*
	mp4_box* my_root = parse_mp4_file(srcfile,1);
	if (my_root == NULL) {
		return -1;
	}
	int start_time = 0,end_time = -1;
	if (start > 0) {
		start_time = start;
	}
	if (end > 0) {
		end_time = end;
	} 
	moov_box* moov = (moov_box*)my_root->get("moov");
	std::vector<mp4_sample*> my_samples;
	moov->seek(my_samples,start_time,end_time);
	std::sort(my_samples.begin(),my_samples.end(),mp4_sample_timecode_cmp);

	TS_Packetizer* tspacketizer = new TS_Packetizer();
	trak_box* vide = moov->get_trak(0x76696465);
	avcC_box* avcC = (avcC_box*)vide->get("mdia")->get("minf")->get("stbl")->get("stsd")->get("avc1")->get("avcC");
	trak_box* sund = moov->get_trak(0x736f756e);
	mp4a_box* mp4a = (mp4a_box*)sund->get("mdia")->get("minf")->get("stbl")->get("stsd")->get("mp4a");
	esds_box* esds = (esds_box*)mp4a->get("esds");
	unsigned char aac_profile = 0;
	unsigned char aac_frequency = 0;
	unsigned char aac_channel = 0;
	uint32_t frame_duration = 0;
	uint32_t audio_pts  = 0;
	//AudioSpecificConfig
	unsigned short asc =  ntohs(*((unsigned short*)esds->AudioSpecificConfig.data()));
	aac_profile = ((asc >> 11) & 0x1f) - 1;
	aac_frequency = (asc >> 7) & 0x0f;
	aac_channel = (asc >> 3) & 0x0f;

	const static uint32_t acc_sampling_frequency[16] = {96000,88200,64000,48000,44100,32000,24000,22050,16000,2000,11025,8000,0,0,0,0};        
	frame_duration = (1024 * 90000 / acc_sampling_frequency[aac_frequency]);

	char buffer[256*1024];
	FILE* rf = fopen(destfile,"wb");
	if (rf != NULL) {
		std::string pat_pmt;
		tspacketizer->set_pat(pat_pmt);
		tspacketizer->set_pmt(pat_pmt);
		fwrite(pat_pmt.data(),1,pat_pmt.length(),rf);
		FILE* f = fopen(srcfile,"rb");
		mp4_sample* sample0 = my_samples[0];
		for (unsigned int j = 0; j < my_samples.size();j++)  {
			mp4_sample* sample = my_samples[j];
			uint32_t pts = (sample->timecode - sample0->timecode) + pts0;

			size_t blocksize = sample->size;
			fseek(f,sample->offset,SEEK_SET);
			size_t ret = fread(buffer,1,sample->size,f);
			if (ret > 0) {
			} else {
				break;
			}
			std::string ts;
			if (sample->vide) {
				std::string es;
				std::string tail;
				char h264_start_code[4] = {0x00,0x00,0x00,0x01};
				int h264_delimiter = 0,h264_sps = 0,h264_pps = 0;   
				int nalu_delimiter = (sample->keyframe == 1)?0x10:0x30;
				int pos = 0;
				while (pos < sample->size) {
					unsigned int packet_length = htonl(*((unsigned int*)&buffer[pos]));
					pos += 4;
					unsigned char nal_unit_type = buffer[pos] & 0x1f;
					if (nal_unit_type == 0x07) {
						h264_sps = 1;
					} else if (nal_unit_type == 0x08) {
						h264_pps = 1;
					} else if (nal_unit_type == 0x09) {
						nalu_delimiter = buffer[pos + 1];
					} 
					if (nal_unit_type != 0x09) {
						tail.append(h264_start_code,4);
						tail.append((const char*)&buffer[pos],packet_length);
					}
					pos += packet_length;
				}
				es.append(h264_start_code,4);
				es.append(1,0x09);
				es.append(1,nalu_delimiter);
				if (sample->keyframe == 1) {
					if (!h264_sps) {
						es.append(h264_start_code,4);
						es.append(avcC->SequenceParameterSet);
					}
					if (!h264_pps) {
						es.append(h264_start_code,4);
						es.append(avcC->PictureParameterSet);
					}
				}
				es.append(tail);
				tspacketizer->es2ts(ts,0x1b,es,pts * 90,pts * 90,sample->keyframe);
			} else {
				std::string es;
				unsigned short frame_length = sample->size;
				unsigned int num_data_block = frame_length / 1024;
				frame_length += 7;
				char adts_header[7];
				adts_header[0] = 0xFF;
				adts_header[1] = 0xF1;
				adts_header[2] = aac_profile << 6;
				adts_header[2] |= (aac_frequency << 2);
				adts_header[2] |= (aac_channel & 0x4) >> 2;
				adts_header[3] = (aac_channel & 0x3) << 6;
				adts_header[3] |= (frame_length & 0x1800) >> 11;
				adts_header[4] = (frame_length & 0x1FF8) >> 3;
				adts_header[5] = (frame_length & 0x7) << 5;
				adts_header[5] |= 0x1F;
				adts_header[6] = 0xFC;
				adts_header[6] |= num_data_block & 0x03;
				es.append(adts_header,7);
				es.append(buffer,sample->size);
				tspacketizer->es2ts(ts,0x0f,es,pts * 90,0,0);
				audio_pts += (num_data_block + 1) * frame_duration;
			}
			fwrite(ts.data(),1,ts.length(),rf);
		}
		fclose(f);
	}
	fclose(rf);
	delete tspacketizer;
	for (unsigned int i = 0; i < my_samples.size();i++) {
		delete my_samples[i];
	}
	delete my_root;
	printf("done!\n");
    */
	return 0;
}

int merge_mp4_files(int n,const char *srcfile[],int start[],int end[],const char* destfile)
{
	std::vector<mp4_sample*> my_samples;
	mp4_box* my_root = NULL;

	for (int index = 0; index < n;index++) {
		mp4_box* root = parse_mp4_file(srcfile[index],0);
		if (root == NULL) {
			continue;
		}
		int start_time = 0,end_time = -1;
		if (start[index] > 0) {
			start_time = start[index];
		}
		if (end[index] > 0) {
			end_time = end[index];
		} 
		moov_box* moov = (moov_box*)root->get("moov");
		std::vector<mp4_sample*> samples;
		moov->seek(samples,start_time,end_time);
		for (unsigned int i = 0; i < samples.size();i++) {
			samples[i]->file_index = index; 
		}
		std::copy(samples.begin(),samples.end(),back_inserter(my_samples));
		if (my_root == NULL) {
			my_root = root;
		} else {
			delete root;
		}
	}
	moov_box* moov = (moov_box*)my_root->get("moov");
	moov->set_samples(my_samples); 
	int mdat_total_size = 8;
	for (unsigned int i = 0; i < my_samples.size();i++) {
		mdat_total_size += my_samples[i]->size;
	}
	int mdat_offset = 0;
	std::vector<mp4_box*>& children = my_root->children();
	for (unsigned int i = 0; i < children.size();i++) {
		mp4_box* e = children[i];
		if (strcmp(e->box_type(),"mdat") == 0) {
			continue;
		} else {
			mdat_offset += e->total_size();
		}
	}
	mdat_offset += 8;     
	printf("mdat_total_size = %d,mdat_offset = %d\n",mdat_total_size,mdat_offset);

	int fi = -1;
	int base_index = 0;
	for (unsigned int i = 0; i < my_samples.size();i++) {
		my_samples[i]->old_offset = my_samples[i]->offset;
		if (my_samples[i]->file_index != fi) {
			my_samples[i]->offset = mdat_offset;
			fi = my_samples[i]->file_index;
			base_index = i;
			mdat_offset += my_samples[i]->size;
			continue;
		}
		my_samples[i]->offset = my_samples[base_index]->offset + my_samples[i]->old_offset - my_samples[base_index]->old_offset;
		mdat_offset = my_samples[i]->offset + my_samples[i]->size;
	}

	moov->set_samples(my_samples); 

	char buffer[8192];
	FILE* rf = fopen(destfile,"wb");
	for (unsigned int i = 0; i < children.size();i++) {
		mp4_box* e = children[i];
		if (strcmp(e->box_type(),"mdat") != 0) {
			std::string str;
			e->boxize(str);
			fwrite(str.data(),str.length(),1,rf);
			continue;
		}
	}
	if (1) {
		std::string str;
		swrite_32(str,mdat_total_size);
		str.append("mdat");
		fwrite(str.data(),str.length(),1,rf);
		mp4_sample* first_sample = NULL;
		for (unsigned int j = 0; j < my_samples.size();j++)  {
			mp4_sample* last_sample = my_samples[j];
			if (first_sample == NULL) {
				first_sample = last_sample;
			} 
			if (j == my_samples.size() - 1 || last_sample->file_index != my_samples[j + 1]->file_index) {
				unsigned int pos = first_sample->old_offset;
				size_t blocksize = last_sample->old_offset + last_sample->size - pos;
				FILE* f = fopen(srcfile[last_sample->file_index],"rb");
				fseek(f,pos,SEEK_SET);
				while (blocksize > 0) {
					size_t ret = fread(buffer,1,blocksize > sizeof(buffer)?sizeof(buffer):blocksize,f);
					if (ret > 0) {
						size_t x = fwrite(buffer,1,ret,rf);
						if (x <= 0) {
							break;
						}
						blocksize -= x;
					} else {
						break;
					}
				}
				fclose(f);
				first_sample = NULL;
			}
		}
	}
	fclose(rf);
	for (unsigned int i = 0; i < my_samples.size();i++) {
		delete my_samples[i];
	}
	delete my_root;
	printf("done!\n");	
	return 0;
}


mp4_box::mp4_box(const char* box_type)
{
	strcpy(box_type_,box_type);
	is_container_ = false;
}

mp4_box::~mp4_box() {
	for (int i = 0;i< children_.size();i++) {
		delete children_[i];
	}
}

int mp4_box::boxize(std::string& data)
{
	pack_content();
	if (box_type_[0] == '\0') {
		data.append(content_);
	} else { 
		swrite_32(data,total_size());
		swrite_32(data,htonl(*((unsigned int*)box_type_)));
		data.append(content_);
	}
	return data.length();
}

void mp4_box::pack_content()
{
	if (is_container_) {
		content_.clear();
		pack_preface(content_);
		for (int i = 0;i< children_.size();i++) {
			std::string tmp;
			children_[i]->boxize(tmp);
			content_.append(tmp);
		}
	} 
}

int mp4_box::unpack_content(const char* data,int length,int max_children)
{
	int pos = 0;
	if (is_container_) {
		pos += unpack_preface(data,length);
		while (pos < length) {
			uint64_t total_size = 0;
			char box_type[8] = {0};
			total_size = read_32((unsigned char*)data + pos);
			memcpy(box_type,data + pos + 4,4);
			box_type_[4] = '\0';
			int used = 8;
			if (total_size == 1) {
				total_size = read_64((unsigned char*)data + pos + used);
				used += 8;
			}
			mp4_box* box = factory_->create_mp4_box(box_type);
			add_child(box);
			box->unpack_content(data + pos + used,total_size - used);
			pos += total_size;         
			if (max_children != -1 && children_.size() >= max_children) {
				break;
			}
		}
	} else {
		content_.assign((const char*)data,length);
		pos = length;
	}
	return pos;
}

int mp4_box::total_size() 
{
	int csize = content_size();
	if (box_type_[0] != '\0') {
		csize += 4 + 4;
	}
	return csize;
}

int mp4_box::content_size() 
{
	if (is_container_) {
		int csize = 0;
		for (int i = 0; i < children_.size();i++) {
			csize += children_[i]->total_size();
		}
		return csize;
	}
	return this->content_.length();
}

void mp4_box::add_child(mp4_box* child)
{
	children_.push_back(child);
}

mp4_box* mp4_box::get(const char* box_type)
{
	for (int i = 0; i < children_.size();i++) {
		if (strcmp(children_[i]->box_type(),box_type) == 0) {
			return children_[i];
		}
	}
	return NULL;
}

void mp4_box::dump_box_type(int level)
{
	if (box_type_[0] != '\0') {
		char blank[256];
		memset(blank,' ',level);
		blank[level] = '\0';
		printf("%s[%s]\n",blank,box_type_);
	}
	for (int i = 0; i < children_.size();i++) {
		children_[i]->dump_box_type(level + 1);
	}
}

void mp4_box::dump_dots_box_type(char* path)
{
	if (box_type_[0] != '\0') {
		printf("%s.%s\n",path,box_type_);
	}
	for (int i = 0; i < children_.size();i++) {
		char my_path[256];
		sprintf(my_path,"%s.%s",path,box_type_);
		children_[i]->dump_dots_box_type(my_path);
	}
}

int moov_box::get_samples(std::vector<mp4_sample*>& samples)
{
	std::vector<mp4_box*>& v = children();
	mvhd_box* mvhd = (mvhd_box*)get("mvhd");
	for (int i = 0; i < v.size();i++) {
		if (strcmp(v[i]->box_type(),"trak") == 0) {
			trak_box* trak = (trak_box*)v[i];
			std::vector<mp4_sample*> trak_samples;
			trak->get_samples(trak_samples);
			for (std::vector<mp4_sample*>::iterator it = trak_samples.begin();it != trak_samples.end();it++) {
				(*it)->trak = i;
			}
			std::copy(trak_samples.begin(),trak_samples.end(),back_inserter(samples));  
		}
	}
	std::sort(samples.begin(),samples.end(),mp4_sample_offset_cmp);
	return samples.size();
}

void moov_box::set_samples(std::vector<mp4_sample*>& samples)
{
	std::vector<mp4_box*>& v = children();
	mvhd_box* mvhd = (mvhd_box*)get("mvhd");
	for (int i = 0; i < v.size();i++) {
		if (strcmp(v[i]->box_type(),"trak") == 0) {
			trak_box* trak = (trak_box*)v[i];
			std::vector<mp4_sample*> trak_samples;
			for (std::vector<mp4_sample*>::iterator it = samples.begin();it != samples.end();it++) {
				if ((*it)->trak == i) {
					trak_samples.push_back((*it));
				}
			}
			trak->set_samples(trak_samples,mvhd);
			hdlr_box* hdlr = (hdlr_box*)trak->get("mdia")->get("hdlr");
			if (hdlr->handler_type_ == 0x76696465) { //vide
				mdhd_box* mdhd = (mdhd_box*)trak->get("mdia")->get("mdhd");
				mvhd->duration_ = mdhd->duration_ * mvhd->timescale_ / mdhd->timescale_;   
			}
		}
	}
}

trak_box* moov_box::get_trak(unsigned int handler_type)
{
	std::vector<mp4_box*>& v = children();
	for (int i = 0; i < v.size();i++) {
		if (strcmp(v[i]->box_type(),"trak") == 0) {
			trak_box* trak = (trak_box*)v[i];
			hdlr_box* hdlr = (hdlr_box*)trak->get("mdia")->get("hdlr");
			if (hdlr->handler_type_ == handler_type) {
				return trak;
			}
		}
	}
	return NULL;
}

int moov_box::seek(std::vector<mp4_sample*>& result,int start_time,int end_time)
{
	std::vector<mp4_sample*> samples;
	get_samples(samples);
	int first = 0;
	int last = -1;
	for (int i = 0; i < samples.size(); i++) {
		mp4_sample* sample = samples[i];
		if (sample->keyframe != 1) {
			continue;
		}
		if (start_time < sample->timecode) {
			sample->dump();
			break;
		}
		first = i;
	}
	start_time = samples[first]->timecode;
	printf("first = %d,timecode = %d\n",first,samples[first]->timecode);

	for (int i = first; i < samples.size(); i++) {
		mp4_sample* sample = samples[i];
		if (sample->keyframe != 1) {
			continue;
		}
		if (end_time > 0 && end_time <= sample->timecode) {
			last = i;
			end_time = sample->timecode;
			printf("last = %d,timecode = %d\n",i,sample->timecode);
			sample->dump();
			break;
		}
	}
	for (int i = 0; i < samples.size(); i++) {
		mp4_sample* sample = samples[i];
		if (i < first || (last > 0 && i >= last)) {
			delete sample;
			continue;
		}
		if (start_time > sample->timecode && sample->leader != 1) {
			delete sample;
			continue;
		} else {
			result.push_back(sample);
		}
	}
	return result.size();
}

int trak_box::get_samples(std::vector<mp4_sample*>& samples)
{
	mp4_box* stbl = (mp4_box*)get("mdia")->get("minf")->get("stbl");
	stts_box* stts = (stts_box*)stbl->get("stts"); //time to sample
	stsc_box* stsc = (stsc_box*)stbl->get("stsc"); //sample to chunk 
	stsz_box* stsz = (stsz_box*)stbl->get("stsz"); //sample size
	stco_box* stco = (stco_box*)stbl->get("stco"); //chunk offset
	stss_box* stss = (stss_box*)stbl->get("stss"); //sync sample
	ctts_box* ctts = (ctts_box*)stbl->get("ctts"); //composition time offset table
	mdhd_box* mdhd = (mdhd_box*)get("mdia")->get("mdhd");
	hdlr_box* hdlr = (hdlr_box*)get("mdia")->get("hdlr");
	int vide = 0;
	if (hdlr->handler_type_ == 0x76696465) { //vide
		vide = 1;
	}
	
	int sample_count = 0;
	for (int i = 0; i < stts->entries_.size();i++) {
		sample_count += stts->entries_[i].first;
	}
	for (int i = 0; i < sample_count;i++) {
		mp4_sample* sample = new mp4_sample();
		sample->vide = vide;
		samples.push_back(sample);
	}

	//pts
	uint64_t pts = 0;
	int j = 0;
	for (int entry = 0; entry < stts->entries_.size();entry++) {
		for (int i = 0; i < stts->entries_[entry].first;i++) {
			pts += stts->entries_[entry].second;
			samples[j]->delta = stts->entries_[entry].second;
			samples[j]->pts = pts;
			samples[j]->timecode = pts * 1000 / mdhd->timescale_;
			j += 1;
		}
	}

	//size    
	for (int i = 0; i < stsz->entries_.size();i++) {
		samples[i]->size = stsz->entries_[i];
	}

	//sync sample
	if (stss != NULL) {
		for (int i = 0; i < stss->entries_.size();i++) {
			samples[stss->entries_[i] - 1]->sync = 1;
			if (hdlr->handler_type_ == 0x76696465) {
				samples[stss->entries_[i] - 1]->keyframe = 1;
			}
		}
	}

	//stsc,stco
	int last_chunk = stco->entries_.size() + 1;
	int x = 0;
	for (int i = 0; i < stsc->entries_.size();i++) {
		int next_chunk = (i == stsc->entries_.size() - 1)?last_chunk:stsc->entries_[i + 1].first;
		int first_chunk = stsc->entries_[i].first;
		int samples_per_chunk = stsc->entries_[i].second;
		for (int chunk = first_chunk; chunk < next_chunk;chunk++) {
			samples[x]->chunk = chunk - 1;
			samples[x]->offset = stco->entries_[chunk - 1];
			samples[x]->leader = 1;
			for (j = 1; j < samples_per_chunk;j++) {
				if (x + j >= samples.size()) {
					break;
				}
				samples[x + j]->chunk = chunk - 1;
				samples[x + j]->offset = samples[x + j - 1]->offset + samples[x + j - 1]->size; 
			}
			x += samples_per_chunk;
		}
	}

	//ctts
	if (ctts != NULL) {
		x = 0;
		for (int entry = 0;entry < ctts->entries_.size();entry++) {
			for (int i = 0; i < ctts->entries_[entry].first;i++) {
				samples[x]->cto = ctts->entries_[entry].second;
				x += 1;
			}
		}
	}
	return samples.size();
}

void trak_box::set_samples(std::vector<mp4_sample*>& samples,mvhd_box* mvhd)
{
	mp4_box* stbl = (mp4_box*)get("mdia")->get("minf")->get("stbl");
	stts_box* stts = (stts_box*)stbl->get("stts"); //time to sample
	stsc_box* stsc = (stsc_box*)stbl->get("stsc"); //sample to chunk 
	stsz_box* stsz = (stsz_box*)stbl->get("stsz"); //sample size
	stco_box* stco = (stco_box*)stbl->get("stco"); //chunk offset
	stss_box* stss = (stss_box*)stbl->get("stss"); //sync sample
	ctts_box* ctts = (ctts_box*)stbl->get("ctts"); //composition time offset table
	mdhd_box* mdhd = (mdhd_box*)get("mdia")->get("mdhd");
	tkhd_box* tkhd = (tkhd_box*)get("tkhd");

	//time to sample
	stts->entries_.clear();
	unique_counter(samples,(size_t)&((mp4_sample*)0)->delta,stts->entries_);

	int chunk = 0;
	std::vector<int> chunks;
	for (int i = 0; i < samples.size();i++) {
		if (i == 0 || (samples[i - 1]->chunk == samples[i]->chunk && samples[i - 1]->file_index == samples[i]->file_index)) {
			chunks.push_back(chunk);
			continue;
		}
		chunk += 1;
		chunks.push_back(chunk);
	}
	for (int i = 0; i < samples.size();i++) {
		samples[i]->chunk = chunks[i];
	}
	//sample to chunk
	std::vector<std::pair<int,int> > c2s;
	unique_counter(samples,(size_t)&((mp4_sample*)0)->chunk,c2s);

	int first = 0;		
	stsc->entries_.clear();
	for (int i = 0; i < c2s.size();i++) {
		int count = c2s[i].first;
		int index = c2s[i].second;
		if (count != first) {
			first = count;
			stsc->entries_.push_back(std::make_pair(index + 1,count));
		}
	}

	//sample size
	stsz->entries_.clear();
	mdhd->duration_ = 0;
	for (int i = 0; i < samples.size();i++) {
		stsz->entries_.push_back(samples[i]->size);
		mdhd->duration_ += samples[i]->delta;
	}

	//chunk offset
	stco->entries_.clear();
	chunk = -1;
	for (int i = 0; i< samples.size();i++) {
		if (samples[i]->chunk != chunk) {
			stco->entries_.push_back(samples[i]->offset);
			chunk = samples[i]->chunk;
		}
	}

	//sync sample 
	if (stss != NULL) {
		stss->entries_.clear();
		for (int i = 0; i< samples.size();i++) {
			if (samples[i]->sync == 1) {
				stss->entries_.push_back(i + 1);
			}
		}
	}                                                     

	//composition time offset table
	if (ctts != NULL) {
		ctts->entries_.clear();
		unique_counter(samples,(size_t)&((mp4_sample*)0)->cto,ctts->entries_);
	}

	tkhd->duration_ = mdhd->duration_ * mvhd->timescale_ / mdhd->timescale_;
}


int stts_box::content_size()
{
	return 4 + 4 + entries_.size() * 8;
}

void stts_box::pack_content()
{
	std::string str;
	swrite_32(str,version_flags_); 
	swrite_32(str,entries_.size()); 
	for (int i = 0; i < entries_.size();i++) {
		swrite_32(str,entries_[i].first);
		swrite_32(str,entries_[i].second);
	}
	set_content(str.data(),str.length());
}

int stts_box::unpack_content(const char* data,int length,int max_children)
{
	int pos = 0;
	version_flags_ = read_32((unsigned char*)data + pos); 
	pos += 4;
	int entry_count = read_32((unsigned char*)data + pos); 
	pos += 4;
	for (int i = 0; i <  entry_count;i++) {
		int sample_count = read_32((unsigned char*)data + pos);
		pos += 4;
		int sample_delta = read_32((unsigned char*)data + pos);
		pos += 4;
		entries_.push_back(std::make_pair(sample_count,sample_delta));
	}
	return pos;
}

int stsc_box::content_size()
{
	return 4 + 4 + entries_.size() * 12;
}

void stsc_box::pack_content()
{
	std::string str;
	swrite_32(str,version_flags_); 
	swrite_32(str,entries_.size()); 
	for (int i = 0; i < entries_.size();i++) {
		swrite_32(str,entries_[i].first);
		swrite_32(str,entries_[i].second);
		swrite_32(str,1);
	}
	set_content(str.data(),str.length());
}

int stsc_box::unpack_content(const char* data,int length,int max_children)
{
	int pos = 0;
	version_flags_ = read_32((unsigned char*)data + pos); 
	pos += 4;
	int entry_count = read_32((unsigned char*)data + pos); 
	pos += 4;
	for (int i = 0; i <  entry_count;i++) {
		int first_chunk = read_32((unsigned char*)data + pos); pos += 4;
		int samples_per_chunk = read_32((unsigned char*)data + pos); pos += 4;
		int sample_description_index = read_32((unsigned char*)data + pos); pos += 4;
		entries_.push_back(std::make_pair(first_chunk,samples_per_chunk));
	}
	return pos;
}

int stsz_box::content_size()
{
	if (sample_size_ == 0) {
		return 12 + entries_.size() * 4;
	}
	return 12;   
}

void stsz_box::pack_content()
{
	std::string str;
	swrite_32(str,version_flags_); 
	swrite_32(str,sample_size_);
	swrite_32(str,entries_.size()); 
	if (sample_size_ == 0) {
		for (int i = 0; i < entries_.size();i++) {
			swrite_32(str,entries_[i]);
		}
	}
	set_content(str.data(),str.length());
}

int stsz_box::unpack_content(const char* data,int length,int max_children)
{
	int pos = 0;
	version_flags_ = read_32((unsigned char*)data + pos); 
	pos += 4;
	sample_size_ = read_32((unsigned char*)data + pos);
	pos += 4;
	int entry_count = read_32((unsigned char*)data + pos); 
	pos += 4;
	if (sample_size_ == 0) {
		for (int i = 0; i <  entry_count;i++) {
			int entry_size = read_32((unsigned char*)data + pos);
			pos += 4;
			entries_.push_back(entry_size);
		}
	}
	return pos;
}

int stco_box::content_size()
{
	if (bit64_) {
		return 4 + 4 + entries_.size() * 8;
	} 
	return 4 + 4 + entries_.size() * 4;
}

void stco_box::pack_content()
{
	std::string str;
	swrite_32(str,version_flags_); 
	swrite_32(str,entries_.size()); 
	for (int i = 0; i < entries_.size();i++) {
		if (bit64_) {
			swrite_64(str,entries_[i]);
		} else {
			swrite_32(str,entries_[i]);
		}
	}
	set_content(str.data(),str.length());
}

int stco_box::unpack_content(const char* data,int length,int max_children)
{
	int pos = 0;
	version_flags_ = read_32((unsigned char*)data + pos); 
	pos += 4;
	int entry_count = read_32((unsigned char*)data + pos); 
	pos += 4;
	for (int i = 0; i <  entry_count;i++) {
		int chunk_offset = 0;
		if (bit64_) {
			chunk_offset = read_64((unsigned char*)data + pos);
			pos += 8;
		} else {
			chunk_offset = read_32((unsigned char*)data + pos);
			pos += 4;
		}
		entries_.push_back(chunk_offset);
	}
	return pos;
}

int stss_box::content_size()
{
	return 4 + 4 + entries_.size() * 4;
}

void stss_box::pack_content()
{
	std::string str;
	swrite_32(str,version_flags_); 
	swrite_32(str,entries_.size()); 
	for (int i = 0; i < entries_.size();i++) {
		swrite_32(str,entries_[i]);
	}
	set_content(str.data(),str.length());
}

int stss_box::unpack_content(const char* data,int length,int max_children)
{
	int pos = 0;
	version_flags_ = read_32((unsigned char*)data + pos); 
	pos += 4;
	int entry_count = read_32((unsigned char*)data + pos); 
	pos += 4;
	for (int i = 0; i <  entry_count;i++) {
		int sample_number = read_32((unsigned char*)data + pos);
		entries_.push_back(sample_number);
		pos += 4;
	}
	return pos;
}

int ctts_box::content_size()
{
	return 4 + 4 + entries_.size() * 8;
}

void ctts_box::pack_content()
{
	std::string str;
	swrite_32(str,version_flags_); 
	swrite_32(str,entries_.size()); 
	for (unsigned int i = 0; i < entries_.size();i++) {
		swrite_32(str,entries_[i].first);
		swrite_32(str,entries_[i].second);
	}
	set_content(str.data(),str.length());
}

int ctts_box::unpack_content(const char* data,int length,int max_children)
{
	int pos = 0;
	version_flags_ = read_32((unsigned char*)data + pos); 
	pos += 4;
	int entry_count = 0;
	entry_count = read_32((unsigned char*)data + pos); 
	pos += 4;
	for (int i = 0; i <  entry_count;i++) {
		int sample_count = read_32((unsigned char*)data + pos);
		pos += 4;
		int sample_offset = read_32((unsigned char*)data + pos);
		pos += 4;
		entries_.push_back(std::make_pair(sample_count,sample_offset));
	}
	return pos;
}

void mvhd_box::pack_content()
{
	std::string str;
	if (version_ == 1) {
		swrite_32(str,timescale_);
		swrite_64(str,duration_); 
		change_content(4 + 8 + 8,str.data(),str.length());
	} else {
		swrite_32(str,timescale_);
		swrite_32(str,(uint32_t)duration_); 
		change_content(4 + 4 + 4,str.data(),str.length());
	}
}

int mvhd_box::unpack_content(const char* data,int length,int max_children)
{
	version_ = data[0];
	if (version_ == 1) {
		timescale_ = read_32((unsigned char*)data + 4 + 8 + 8);
		duration_ = read_64((unsigned char*)data + 4 + 8 + 8 + 8);
	}else {
		timescale_ = read_32((unsigned char*)data + 4 + 4 + 4);
		duration_ = read_32((unsigned char*)data + 4 + 4 + 4 + 4);
	}
	return mp4_box::unpack_content(data,length,max_children);
}

void tkhd_box::pack_content()
{
	std::string str;
	if (version_ == 1) {
		swrite_64(str,duration_); 
		change_content(28,str.data(),str.length());
	} else {
		swrite_32(str,(uint32_t)duration_);
		change_content(20,str.data(),str.length());
	}
}

int tkhd_box::unpack_content(const char* data,int length,int max_children)
{
	version_ = data[0];
	if (version_ == 1) {
		duration_ = read_64((unsigned char*)data + 28); 
	}else {
		duration_ = read_32((unsigned char*)data + 20); 
	}
	return mp4_box::unpack_content(data,length,max_children);
}

void mdhd_box::pack_content()
{
	std::string str;
	if (version_ == 1) {
		swrite_32(str,timescale_);
		swrite_64(str,duration_); 
		change_content(4 + 8 + 8,str.data(),str.length());
	} else {
		swrite_32(str,timescale_);
		swrite_32(str,(uint32_t)duration_); 
		change_content(4 + 4 + 4,str.data(),str.length());
	}
}

int mdhd_box::unpack_content(const char* data,int length,int max_children)
{
	version_ = data[0];
	if (version_ == 1) {
		timescale_ = read_32((unsigned char*)data + 4 + 8 + 8);
		duration_ = read_64((unsigned char*)data + 4 + 8 + 8 + 4);
	}else {
		timescale_ = read_32((unsigned char*)data + 4 + 4 + 4);
		duration_ = read_32((unsigned char*)data + 4 + 4 + 4 + 4);
	}
	return mp4_box::unpack_content(data,length,max_children);
}

int hdlr_box::unpack_content(const char* data,int length,int max_children)
{
	handler_type_ = read_32((unsigned char*)data + 8);
	return mp4_box::unpack_content(data,length,max_children);
}

int avcC_box::unpack_content(const char* data,int length,int max_children)
{
	int pos = 0;
	unsigned char configurationVersion = data[pos]; pos += 1;
	unsigned char AVCProfileIndication = data[pos]; pos += 1;
	unsigned char profile_compatibility = data[pos]; pos += 1;
	unsigned char AVCLevelIndication = data[pos]; pos += 1;
	unsigned char lengthSizeMinusOne = data[pos] & 0x03; pos += 1;
	unsigned char numOfSequenceParameterSets = data[pos] & 0x1f; pos += 1;
	for (int i = 0; i< numOfSequenceParameterSets; i++) {
		unsigned short sequenceParameterSetLength = ntohs(*((unsigned short*)&data[pos]));
		pos += 2;
		SequenceParameterSet.append(&data[pos],sequenceParameterSetLength);
		pos += sequenceParameterSetLength;
	}
	unsigned int numOfPictureParameterSets = data[pos]; pos += 1;
	for (int i = 0; i< numOfPictureParameterSets; i++) {
		unsigned short pictureParameterSetLength = ntohs(*((unsigned short*)&data[pos]));
		pos += 2;
		PictureParameterSet.append(&data[pos],pictureParameterSetLength);
		pos += pictureParameterSetLength;
	}
	return mp4_box::unpack_content(data,length,max_children);
}

int esds_box::unpack_content(const char* data,int length,int max_children)
{
	int pos = 0;
	pos += 4;
	while (pos < length) {
		int len = 0;
		unsigned char tag = 0;
		tag = data[pos]; pos += 1;
		for (int i = 0; i < 4;i++) {
			unsigned char c = data[pos]; pos += 1;
			len = (len << 7) | (c & 0x7f);
			if ((c & 0x80) == 0) break; 
		}
		if (tag == 0x03) {
			pos += 3;
		} else if (tag == 0x04) {
			pos += 13;
		} else if (tag == 0x05) {
			AudioSpecificConfig.append(&data[pos],len);
			pos += len;
		} else if (tag == 0x06) {
			pos += len;
		} else {
			break;
		}
	}
	return mp4_box::unpack_content(data,length,max_children);
}
