#include "TS_Packetizer.h"

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

#define MAX_ES_LEN 65522 
#define TS_PKT_SIZE 188
static const int dvbpsi_crc32_table[256] = {
	0x00000000, 0x04c11db7, 0x09823b6e, 0x0d4326d9,
		0x130476dc, 0x17c56b6b, 0x1a864db2, 0x1e475005,
		0x2608edb8, 0x22c9f00f, 0x2f8ad6d6, 0x2b4bcb61,
		0x350c9b64, 0x31cd86d3, 0x3c8ea00a, 0x384fbdbd,
		0x4c11db70, 0x48d0c6c7, 0x4593e01e, 0x4152fda9,
		0x5f15adac, 0x5bd4b01b, 0x569796c2, 0x52568b75,
		0x6a1936c8, 0x6ed82b7f, 0x639b0da6, 0x675a1011,
		0x791d4014, 0x7ddc5da3, 0x709f7b7a, 0x745e66cd,
		0x9823b6e0, 0x9ce2ab57, 0x91a18d8e, 0x95609039,
		0x8b27c03c, 0x8fe6dd8b, 0x82a5fb52, 0x8664e6e5,
		0xbe2b5b58, 0xbaea46ef, 0xb7a96036, 0xb3687d81,
		0xad2f2d84, 0xa9ee3033, 0xa4ad16ea, 0xa06c0b5d,
		0xd4326d90, 0xd0f37027, 0xddb056fe, 0xd9714b49,
		0xc7361b4c, 0xc3f706fb, 0xceb42022, 0xca753d95,
		0xf23a8028, 0xf6fb9d9f, 0xfbb8bb46, 0xff79a6f1,
		0xe13ef6f4, 0xe5ffeb43, 0xe8bccd9a, 0xec7dd02d,
		0x34867077, 0x30476dc0, 0x3d044b19, 0x39c556ae,
		0x278206ab, 0x23431b1c, 0x2e003dc5, 0x2ac12072,
		0x128e9dcf, 0x164f8078, 0x1b0ca6a1, 0x1fcdbb16,
		0x018aeb13, 0x054bf6a4, 0x0808d07d, 0x0cc9cdca,
		0x7897ab07, 0x7c56b6b0, 0x71159069, 0x75d48dde,
		0x6b93dddb, 0x6f52c06c, 0x6211e6b5, 0x66d0fb02,
		0x5e9f46bf, 0x5a5e5b08, 0x571d7dd1, 0x53dc6066,
		0x4d9b3063, 0x495a2dd4, 0x44190b0d, 0x40d816ba,
		0xaca5c697, 0xa864db20, 0xa527fdf9, 0xa1e6e04e,
		0xbfa1b04b, 0xbb60adfc, 0xb6238b25, 0xb2e29692,
		0x8aad2b2f, 0x8e6c3698, 0x832f1041, 0x87ee0df6,
		0x99a95df3, 0x9d684044, 0x902b669d, 0x94ea7b2a,
		0xe0b41de7, 0xe4750050, 0xe9362689, 0xedf73b3e,
		0xf3b06b3b, 0xf771768c, 0xfa325055, 0xfef34de2,
		0xc6bcf05f, 0xc27dede8, 0xcf3ecb31, 0xcbffd686,
		0xd5b88683, 0xd1799b34, 0xdc3abded, 0xd8fba05a,
		0x690ce0ee, 0x6dcdfd59, 0x608edb80, 0x644fc637,
		0x7a089632, 0x7ec98b85, 0x738aad5c, 0x774bb0eb,
		0x4f040d56, 0x4bc510e1, 0x46863638, 0x42472b8f,
		0x5c007b8a, 0x58c1663d, 0x558240e4, 0x51435d53,
		0x251d3b9e, 0x21dc2629, 0x2c9f00f0, 0x285e1d47,
		0x36194d42, 0x32d850f5, 0x3f9b762c, 0x3b5a6b9b,
		0x0315d626, 0x07d4cb91, 0x0a97ed48, 0x0e56f0ff,
		0x1011a0fa, 0x14d0bd4d, 0x19939b94, 0x1d528623,
		0xf12f560e, 0xf5ee4bb9, 0xf8ad6d60, 0xfc6c70d7,
		0xe22b20d2, 0xe6ea3d65, 0xeba91bbc, 0xef68060b,
		0xd727bbb6, 0xd3e6a601, 0xdea580d8, 0xda649d6f,
		0xc423cd6a, 0xc0e2d0dd, 0xcda1f604, 0xc960ebb3,
		0xbd3e8d7e, 0xb9ff90c9, 0xb4bcb610, 0xb07daba7,
		0xae3afba2, 0xaafbe615, 0xa7b8c0cc, 0xa379dd7b,
		0x9b3660c6, 0x9ff77d71, 0x92b45ba8, 0x9675461f,
		0x8832161a, 0x8cf30bad, 0x81b02d74, 0x857130c3,
		0x5d8a9099, 0x594b8d2e, 0x5408abf7, 0x50c9b640,
		0x4e8ee645, 0x4a4ffbf2, 0x470cdd2b, 0x43cdc09c,
		0x7b827d21, 0x7f436096, 0x7200464f, 0x76c15bf8,
		0x68860bfd, 0x6c47164a, 0x61043093, 0x65c52d24,
		0x119b4be9, 0x155a565e, 0x18197087, 0x1cd86d30,
		0x029f3d35, 0x065e2082, 0x0b1d065b, 0x0fdc1bec,
		0x3793a651, 0x3352bbe6, 0x3e119d3f, 0x3ad08088,
		0x2497d08d, 0x2056cd3a, 0x2d15ebe3, 0x29d4f654,
		0xc5a92679, 0xc1683bce, 0xcc2b1d17, 0xc8ea00a0,
		0xd6ad50a5, 0xd26c4d12, 0xdf2f6bcb, 0xdbee767c,
		0xe3a1cbc1, 0xe760d676, 0xea23f0af, 0xeee2ed18,
		0xf0a5bd1d, 0xf464a0aa, 0xf9278673, 0xfde69bc4,
		0x89b8fd09, 0x8d79e0be, 0x803ac667, 0x84fbdbd0,
		0x9abc8bd5, 0x9e7d9662, 0x933eb0bb, 0x97ffad0c,
		0xafb010b1, 0xab710d06, 0xa6322bdf, 0xa2f33668,
		0xbcb4666d, 0xb8757bda, 0xb5365d03, 0xb1f740b4
};

static const int mp3_sampling_frequency[4] = {44100,48000,32000,-1};
static const int V1L3[16] = {0,32,40,48,56,64,80,96,112,128,160,192,224,256,320,-1};

void adaptation_field(std::string& af,uint8_t random_access_indicator,uint8_t adaptation_field_control,uint8_t pcr_flag,uint32_t pts,uint8_t stuffing_bytes_len,uint8_t zero_adaptation_field_length)
{
	int adaptation_field_length = 0;
	if (adaptation_field_control == 1) {
		adaptation_field_length = 1 + pcr_flag * 6 + stuffing_bytes_len;
		if (zero_adaptation_field_length && pcr_flag == 0 && stuffing_bytes_len == 0) {
			adaptation_field_length = 0;
		}
		swrite_8(af,adaptation_field_length);
	}
	if (adaptation_field_length > 0) {
		uint8_t discontinuity_indicator = 0;
		uint8_t elementary_stream_priority_indicator= 0;
		uint8_t opcr_flag = 0;
		uint8_t splicing_point_flag = 0;
		uint8_t transport_private_data_flag = 0;
		uint8_t adaptation_field_extension_flag = 0;
		swrite_8(af,(random_access_indicator << 6) | (pcr_flag << 4));
		if (pcr_flag == 1) {
			uint32_t pcr_base = pts; 
			swrite_32(af,(pcr_base >> 1));
			if ((pcr_base % 2) == 0) {
				af.append(1,0x7e);
			} else {
				af.append(1,0xfe);
			}
			af.append(1,0x00);
		}
		if (stuffing_bytes_len) {
			af.append(stuffing_bytes_len,0xff);
		}
	}
}

TS_Packetizer::TS_Packetizer()
{
	program_number_ = 1;
	program_map_pid_ = 4095;
	vpid_ = 256;
	vstream_type_ = 0x1b;
	apid_ = 257;
	astream_type_ = 0x0f;
	pcr_pid_ = 256;
	stream_types_[0x1b] = vpid_;
	stream_types_[0x03] = apid_;
	stream_types_[0x0f] = apid_;
	memset(cc_,0,sizeof(cc_));
}

TS_Packetizer::~TS_Packetizer(void)
{

}

void TS_Packetizer::set_pat(std::string& pat)
{
	std::string str;
	tsheader(str,1,0,0,1);

	uint8_t transport_stream_id = 1;
	uint8_t pointer_field =  0;
	uint8_t table_id =  0;
	uint8_t section_syntax_indicator =  1;
	uint8_t private_indicator =  0;
	uint8_t version_number =  0;
	uint8_t current_next_indicator =  1;
	uint8_t section_number =  0;
	uint8_t last_section_number =  0;
	uint8_t reserved1 = 0x03,reserved2 = 0x03,reserved3 = 0x07;
	swrite_8(str,pointer_field);
	swrite_8(str,table_id);
	std::string section = "";
	if (section_syntax_indicator == 1) {
		swrite_16(section,transport_stream_id);
		swrite_8(section,(reserved2 << 6) | version_number << 1 | current_next_indicator);
		swrite_8(section,section_number);
		swrite_8(section,last_section_number);
	}
	swrite_16(section,program_number_);
	swrite_16(section,(reserved3 << 13) | program_map_pid_);
	uint16_t section_length = section.length() + 4;            
	swrite_16(str,section_syntax_indicator << 15  | private_indicator << 14 | (reserved1 << 12) | section_length);
	str += section;
	uint32_t crc = 0xffffffff;
	for (int x = 5; x < str.length();x++) {
		crc = ((crc & 0x00ffffff) << 8) ^ dvbpsi_crc32_table[(crc >> 24) ^ (uint8_t)str[x]];
	}
	swrite_32(str,crc);
	str.append((188 - str.length()),0xff);
	pat.append(str);
}

void TS_Packetizer::set_pmt(std::string& pmt)
{
	std::string str;
	tsheader(str,1,program_map_pid_,0,1);

	uint8_t pointer_field =  0;
	uint8_t table_id =  2;
	uint8_t section_syntax_indicator =  1;
	uint8_t private_indicator =  0;
	uint8_t version_number =  0;
	uint8_t current_next_indicator =  1;
	uint8_t section_number = 0  ;
	uint8_t last_section_number = 0;
	uint8_t reserved1 = 0x03,reserved2 = 0x03,reserved3 = 0x07,reserved4 = 0x0f;  
	swrite_8(str,pointer_field);
	swrite_8(str,table_id);
	std::string section = "";
	if (section_syntax_indicator == 1) {
		swrite_16(section,program_number_);
		swrite_8(section,(reserved2 << 6) | version_number << 1 | current_next_indicator);
		swrite_8(section,section_number);
		swrite_8(section,last_section_number);
	}
	std::map<int,std::string> program_infos;
	std::string program_info = "";
	std::map<int,std::string>::iterator it;
	for (it = program_infos.begin(); it != program_infos.end();it++) {
		swrite_8(program_info,it->first);
		swrite_8(program_info,it->second.length());
		program_info += it->second;
	}
	swrite_16(section,(reserved3 << 13) | pcr_pid_);
	swrite_16(section,(reserved4 << 12) | program_info.length());
	section += program_info; 
	swrite_8(section,vstream_type_);
	swrite_16(section,(reserved3 << 13) | vpid_);
	swrite_16(section,(reserved4 << 12) | vinfo_.length());
	swrite_8(section,astream_type_);
	swrite_16(section,(reserved3 << 13) | apid_);
	swrite_16(section,(reserved4 << 12) | ainfo_.length());
	uint8_t section_length = section.length() + 4;
	swrite_16(str,section_syntax_indicator << 15  | private_indicator << 14 | (reserved1 << 12) | section_length);
	str += section;            
	uint32_t crc = 0xffffffff;
	for (int x = 5; x < str.length();x++) {
		crc = ((crc & 0x00ffffff) << 8) ^ dvbpsi_crc32_table[(crc >> 24) ^ (uint8_t)str[x]];
	}
	swrite_32(str, crc);
	str.append((188 - str.length()),0xff);
	pmt.append(str);
}

void TS_Packetizer::es2ts(std::string& ts,uint8_t stream_type,std::string& es,uint32_t pts,uint32_t dts,uint8_t keyframe)
{
	std::string pes;
	uint8_t stream_id = (stream_type == 0x1b)?0xe0:0xc0;
	es2pes(pes,stream_id,pts,dts,es);
	uint16_t pid = stream_types_[stream_type];
	pes2ts(ts,pid,pes,pts,keyframe);
}

uint32_t TS_Packetizer::es2ts_len(uint8_t stream_type,uint32_t es_len,uint32_t pts,uint32_t dts,uint8_t keyframe)
{
	uint8_t stream_id = (stream_type == 0x1b)?0xe0:0xc0;
	uint32_t pes_len = es2pes_len(stream_id,pts,dts,es_len);
	uint16_t pid = stream_types_[stream_type];
	return pes2ts_len(pid,pes_len,pts,keyframe);
}

void TS_Packetizer::tsheader(std::string& th,uint8_t payload_unit_start_indicator,uint16_t pid,uint8_t adaptation_field_control,uint8_t payload_data_exist)
{
	uint8_t continuity_counter = cc_[pid];
	cc_[pid] = (cc_[pid] + 1) % 16;
	uint8_t scrambling_control = 0;
	swrite_8(th,0x47);
	swrite_16(th,(payload_unit_start_indicator << 14) | pid);
	swrite_8(th,(adaptation_field_control << 5) | (payload_data_exist << 4) | continuity_counter);
}

void TS_Packetizer::es2pes(std::string& pes,uint8_t stream_id,uint32_t pts,uint32_t dts,std::string& es)
{
	const char* start_code = "\x00\x00\x01";
	pes.append(start_code,3);
	uint8_t pts_flags = 1;
	uint8_t dts_flags = 0;
	if (stream_id == 0xe0) {
		dts_flags = 1;
	}
	uint8_t pes_header_data_length = 5 * (pts_flags + dts_flags);
	uint16_t pes_packet_length = 2 + (1 + pes_header_data_length) +  es.length();
	if (pes_packet_length > 65535) {
		pes_packet_length = 0;
	}
	uint8_t PES_scrambling_control = 0,PES_priority = 0,data_alignment_indicator = 1,copyright = 0,original_or_copy = 0;

	uint8_t b6 = (2 << 6) | (PES_scrambling_control << 4) | (PES_priority << 3) | (data_alignment_indicator << 2) | (copyright << 1) | original_or_copy;
	uint8_t ESCR_flag = 0,ES_rate_flag = 0,DSM_trick_mode_flag = 0,additional_copy_info_flag = 0,PES_CRC_flag = 0;
	uint8_t b7 = (pts_flags << 7) | (dts_flags << 6) | ESCR_flag | ES_rate_flag | DSM_trick_mode_flag | additional_copy_info_flag | PES_CRC_flag; 
	swrite_8(pes,stream_id);
	swrite_16(pes, pes_packet_length);
	swrite_8(pes, b6);
	swrite_8(pes, b7);
	swrite_8(pes, pes_header_data_length);
	int k = 0;
	while (k < pts_flags + dts_flags) {
		uint32_t which = pts;
		if (k == 1) {
			which = dts;
		}
		uint32_t pts1 = which / (32768 * 32768);
		uint32_t pts2 = (which - pts1 * 32768 * 32768) / 32768;
		uint32_t pts3 = which % 32768;
		if (dts_flags == 1) {
			swrite_8(pes,((k == 0)?0x30:0x10) | (pts1 << 1) | 0x01);
		} else {
			swrite_8(pes,0x20 | (pts1 << 1) | 0x01);                        
		}
		swrite_16(pes,(pts2 << 1) | 0x01);
		swrite_16(pes, (pts3 << 1) | 0x01);
		k += 1;
	}
	pes += es;
}

uint32_t TS_Packetizer::es2pes_len(uint8_t stream_id,uint32_t pts,uint32_t dts,uint32_t es_len)
{
	uint8_t pes_header_data_length = 5 * ((stream_id == 0xe0)?2:1);
	return 3 + 2 + (1 + pes_header_data_length) +  es_len;
}

void TS_Packetizer::pes2ts(std::string& ts,uint16_t pid,std::string& pes,uint32_t pts,uint8_t keyframe)
{
	uint8_t payload_unit_start_indicator = 1;
	uint8_t pcr_flag = 0;
	if (pid == vpid_) {
		pcr_flag = 1;
	}
	int pos = 0;
	while (pos < pes.length()) {
		int rest = pes.length() - pos;	
		uint8_t adaptation_field_control = 0;
		uint8_t stuffing_bytes_len = 0;
		uint8_t extra = 4;
		uint8_t zero_adaptation_field_length = 0;
		if (pcr_flag == 1) {
			extra += 1 + (1 + pcr_flag * 6);
		}
		if (rest < 188 - extra) {
			if (pcr_flag == 0) {
				extra += 1 + ((rest == 183)?0:1) + pcr_flag * 6;
				if (rest == 183){ 
					zero_adaptation_field_length = 1;
				}
			}
			stuffing_bytes_len = 188 - extra - rest;
		}
		if (extra > 4) {
			adaptation_field_control = 1;
		}
		uint8_t payload_data_exist = 1;  
		std::string header;
		tsheader(header,payload_unit_start_indicator,pid,adaptation_field_control,payload_data_exist);
		uint8_t random_access_indicator = (payload_unit_start_indicator == 1 && keyframe)?1:0;
		adaptation_field(header,random_access_indicator,adaptation_field_control,pcr_flag,pts,stuffing_bytes_len,zero_adaptation_field_length);
		ts.append(header);
		ts.append(pes.data() + pos,188 - header.length());
		pos += 188 - header.length();  
		payload_unit_start_indicator = 0;
		pcr_flag = 0;
	}
}

uint32_t TS_Packetizer::pes2ts_len(uint16_t pid,uint32_t pes_len,uint32_t pts,uint8_t keyframe)
{
	uint32_t ts_len = 0;
	uint8_t payload_unit_start_indicator = 1;
	uint8_t pcr_flag = 0;
	if (pid == vpid_) {
		pcr_flag = 1;
	}
	int pos = 0;
	while (pos < pes_len) {
		int rest = pes_len - pos;	
		uint8_t adaptation_field_control = 0;
		uint8_t stuffing_bytes_len = 0;
		uint8_t extra = 4;
		uint8_t zero_adaptation_field_length = 0;
		if (pcr_flag == 1) {
			extra += 1 + (1 + pcr_flag * 6);
		}
		if (rest < 188 - extra) {
			if (pcr_flag == 0) {
				extra += 1 + ((rest == 183)?0:1) + pcr_flag * 6;
				if (rest == 183){ 
					zero_adaptation_field_length = 1;
				}
			}
			stuffing_bytes_len = 188 - extra - rest;
		}
		if (extra > 4) {
			adaptation_field_control = 1;
		}
		uint8_t payload_data_exist = 1;  
		int adaptation_field_length = 0;
		if (adaptation_field_control == 1) {
			adaptation_field_length = 1 + pcr_flag * 6 + stuffing_bytes_len;
		}
		if (zero_adaptation_field_length && pcr_flag == 0 && stuffing_bytes_len == 0) {
			adaptation_field_length = 0;
		}
		ts_len += 188;
		pos += 188 - (4 + adaptation_field_length);  
		payload_unit_start_indicator = 0;
		pcr_flag = 0;
	}
	return ts_len;
}