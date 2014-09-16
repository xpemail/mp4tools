#ifndef TS_PACKETIZER_H
#define TS_PACKETIZER_H

#ifdef WIN32
typedef unsigned char uint8_t;
typedef unsigned short uint16_t;
typedef unsigned int uint32_t;
typedef char int8_t;
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
#include <list>
#include <string>
#include <string.h>
#include <map>

class TS_Packetizer
{
public:
	TS_Packetizer();
	virtual ~TS_Packetizer();
public:
	void set_pat(std::string& pat);
	void set_pmt(std::string& pmt);
	void es2ts(std::string& ts,uint8_t stream_type,std::string& es,uint32_t pts,uint32_t dts,uint8_t keyframe);
	uint32_t es2ts_len(uint8_t stream_type,uint32_t es_len,uint32_t pts,uint32_t dts,uint8_t keyframe);
private:
	void tsheader(std::string& th,uint8_t payload_unit_start_indicator,uint16_t pid,uint8_t adaptation_field_control,uint8_t payload_data_exist);
	void es2pes(std::string& pes,uint8_t stream_id,uint32_t pts,uint32_t dts,std::string& es);
	uint32_t es2pes_len(uint8_t stream_id,uint32_t pts,uint32_t dts,uint32_t es_len);
	void pes2ts(std::string& ts,uint16_t pid,std::string& pes,uint32_t pts,uint8_t keyframe);
	uint32_t pes2ts_len(uint16_t pid,uint32_t pes_len,uint32_t pts,uint8_t keyframe);
private:
	uint8_t cc_[8192];
	uint16_t program_map_pid_;
	uint16_t program_number_;
	std::map<int,int,std::less<int> > stream_types_;
	uint16_t vpid_;
	std::string vinfo_;
	uint8_t astream_type_;
	uint8_t vstream_type_;
	uint16_t apid_;
	std::string ainfo_;
	uint16_t pcr_pid_;
};

#endif

