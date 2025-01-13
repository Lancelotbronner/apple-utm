//
//  VMKeyboardMapping.h
//  CoreUTM
//
//  Created by Christophe Bronner on 2025-01-13.
//

#pragma once

#include <stdint.h>

struct key_mapping_t {
	char tc;
	int prekey;
	int special_prekey;
	int special_key;
	int key;
};

struct ext_key_mapping_t {
	char tc;
	char ext1;
	char ext2;
	int prekey;
	int special_prekey;
	int special_key;
	int key;
};

const struct ext_key_mapping_t pc104_es_ext[];
const struct key_mapping_t pc104_es[];

const struct ext_key_mapping_t pc104_us_ext[];
const struct key_mapping_t pc104_us[];


int keymap_index_of(const struct key_mapping_t *table, size_t table_len, char tc);

int keymap_index_of_ext(const struct ext_key_mapping_t *table, size_t table_len, char tc, char ext1, char ext2);
