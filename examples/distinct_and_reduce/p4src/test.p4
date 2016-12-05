#include "includes/headers.p4"
#include "includes/parser.p4"

parser start {
	return select(current(0, 64)) {
		0 : parse_out_header;
		default: parse_ethernet;
	}
}
action _drop() {
	drop();
}

action _nop() {
	no_op();
}

parser parse_out_header {
	extract(out_header_2);
	return parse_ethernet;
}

header_type out_header_2_t {
	fields {
		qid : 8;
		dIP : 32;
		count : 8;
	}
}

header out_header_2_t out_header_2;

field_list copy_to_cpu_fields_2{
	standard_metadata;
	meta_reduce_0_2;
	meta_fm;
}

action do_copy_to_cpu_2() {
	clone_ingress_pkt_to_egress(202, copy_to_cpu_fields_2);
}

table copy_to_cpu_2 {
	actions {do_copy_to_cpu_2;}
	size : 1;
}

table encap_2 {
	actions { do_encap_2; }
	size : 1;
}

action do_encap_2() {
	add_header(out_header_2);
	modify_field(out_header_2.qid, meta_reduce_0_2.qid);
	modify_field(out_header_2.dIP, ipv4.dstAddr);
	modify_field(out_header_2.count, meta_reduce_0_2.val);
}

table skip_reduce_0_2_1 {
	actions {_nop;}
	size : 1;
}

table drop_reduce_0_2_1 {
	actions {_drop;}
	size : 1;
}

header_type meta_reduce_0_2_t {
	fields {
		qid : 8;
		val : 32;
		idx : 32;
	}
}

metadata meta_reduce_0_2_t meta_reduce_0_2;

header_type hash_meta_reduce_0_2_t {
	fields {
		dIP : 32;
	}
}

metadata hash_meta_reduce_0_2_t hash_meta_reduce_0_2;

field_list reduce_0_2_fields {
	hash_meta_reduce_0_2.dIP;
}

field_list_calculation reduce_0_2_fields_hash {
	input {
		reduce_0_2_fields;
	}
	algorithm : crc32;
	output_width : 32;
}

register reduce_0_2{
	width : 32;
	instance_count : 16;
}

action update_reduce_0_2_regs() {
	add_to_field(meta_reduce_0_2.val, 1);
	register_write(reduce_0_2,meta_reduce_0_2.idx,meta_reduce_0_2.val);
}

table update_reduce_0_2_counts {
	actions {update_reduce_0_2_regs;}
	size : 1;
}

action do_reduce_0_2_hashes() {
	modify_field(hash_meta_reduce_0_2.dIP, ipv4.dstAddr);
	modify_field(meta_reduce_0_2.qid, 2);
	modify_field_with_hash_based_offset(meta_reduce_0_2.idx, 0, reduce_0_2_fields_hash, 16);
	register_read(meta_reduce_0_2.val, reduce_0_2, meta_reduce_0_2.idx);
}

table start_reduce_0_2 {
	actions {do_reduce_0_2_hashes;}
	size : 1;
}

action set_reduce_0_2_count() {
	modify_field(meta_reduce_0_2.val, 1);
}

table set_reduce_0_2_count {
	actions {set_reduce_0_2_count;}
        size: 1;
}

header_type meta_fm_t {
	fields {
		qid_2 : 1;
	}
}

metadata meta_fm_t meta_fm;

action init_meta_fm() {
	modify_field(meta_fm.qid_2, 0);
}

table init_meta_fm {
	actions {init_meta_fm;}
	size: 1;
}

action set_meta_fm_2(){
	modify_field(meta_fm.qid_2, 1);
}

table filter_2{
	actions{
		set_meta_fm_2;
		_nop;
	}
}

control ingress {
	apply(init_meta_fm);
	apply(filter_2);
	if (meta_fm.qid_2 == 1){
			apply(start_reduce_0_2);
		apply(copy_to_cpu_2);
	}
}

control egress {
	if (meta_fm.qid_2 == 1){
		apply(update_reduce_0_2_counts);
		if(meta_reduce_0_2.val > 2) {
			apply(set_reduce_0_2_count);		}
		else if(meta_reduce_0_2.val == 2) {
			apply(skip_reduce_0_2_1);
		}
		else {
			apply(drop_reduce_0_2_1);
		}


		apply(encap_2);
	}

}