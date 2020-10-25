#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint-gcc.h>
#include <math.h>

#define BYTES_PER_SECTOR 512
#define SECTORS_PER_CLUSTER 64
#define CLUSTER_PER_FILE 1
#define ROOT_SECTORS 1
#define PROP_SECTORS 1
#define VOLUME_NAME_LENGTH 16

typedef struct {
    uint8_t root_sectors;
    uint8_t sectors_per_cluster;
    uint8_t clusters_per_file;
    uint8_t fs_version;
    uint16_t bytes_per_sector;
    uint16_t root_sector_offset;
    uint16_t data_sector_offset;
    char volume_name[VOLUME_NAME_LENGTH];
    uint16_t jump_table_offset;
} __attribute__((packed)) FS_PROPERTIES_NODE;

// root node file entries [16 bytes]
typedef struct {
    uint8_t status;
    char filename[12];
    uint8_t cluster_index;
    uint8_t sectors_used;
    uint8_t reserved;
} __attribute__((packed)) ROOT_NODE;


FILE *g_fout = 0;
uint8_t *buffer = 0;


int main() {
    int properties_node_size = sizeof(FS_PROPERTIES_NODE);
    int properties_block_size = BYTES_PER_SECTOR;
    int max_filesize = (BYTES_PER_SECTOR * SECTORS_PER_CLUSTER);
    int prop_block_size = (BYTES_PER_SECTOR * PROP_SECTORS);
    int root_block_size = (BYTES_PER_SECTOR * ROOT_SECTORS);
    int root_node_size = sizeof(ROOT_NODE);
    int max_files = (root_block_size / root_node_size);
    int volume_size = (max_filesize * max_files) + root_block_size + properties_block_size;
    int data_sector_start = root_block_size;
    int prop_start_address = 0;
    int root_start_address = prop_start_address + prop_block_size;
    int data_start_address = root_start_address + root_block_size;

    // fs stats
    printf("Sector size        : %d\n", BYTES_PER_SECTOR);
    printf("Sectors per cluster: %d\n", SECTORS_PER_CLUSTER);
    printf("Cluster size       : %d\n", SECTORS_PER_CLUSTER * BYTES_PER_SECTOR);
    printf("Cluster per file   : %d\n", CLUSTER_PER_FILE);
    printf("Volume Size        : %d\n", volume_size);
    printf("Prop node size     : %d\n", properties_node_size);
    printf("Prop block size:   : %d\n", prop_block_size);
    printf("Root block size    : %d\n", root_block_size);
    printf("Root node size     : %d\n", root_node_size);
    printf("Max files:         : %d\n", max_files);
    printf("Max file size      : %d\n", max_filesize);
    printf("Prop start addr    : 0x%06X\n", prop_start_address);
    printf("Root start addr    : 0x%06X\n", root_start_address);
    printf("Data start addr    : 0x%06X\n", data_start_address);
    printf("Prop start offset  : %d\n", 0);
    printf("Root start offset  : %d\n", PROP_SECTORS);
    printf("Data start offset  : %d\n", PROP_SECTORS + ROOT_SECTORS);


    // make buffer
    buffer = calloc(sizeof(uint8_t), volume_size);

    // make fake properties block
    FS_PROPERTIES_NODE fsprop;
    fsprop.bytes_per_sector = BYTES_PER_SECTOR;
    fsprop.fs_version = 1;
    fsprop.root_sectors = ROOT_SECTORS;
    fsprop.sectors_per_cluster = SECTORS_PER_CLUSTER;
    fsprop.clusters_per_file = CLUSTER_PER_FILE;
    fsprop.root_sector_offset = PROP_SECTORS;
    fsprop.data_sector_offset = PROP_SECTORS + ROOT_SECTORS;
    strcpy(fsprop.volume_name, "VOLUME1");

    // make fake root block
    ROOT_NODE test1;
    ROOT_NODE test2;
    ROOT_NODE test3;
    ROOT_NODE test4;
    strncpy(test1.filename, "TEST1.BIN", 12);
    strncpy(test2.filename, "TEST2.BIN", 12);
    strncpy(test3.filename, "3100HELLO.E", 12);
    strncpy(test4.filename, "DELETED.E", 12);
    test1.status = 1;
    test2.status = 1;
    test3.status = 1;
    test4.status = 0x81;
    test1.cluster_index = 0;
    test2.cluster_index = 1;
    test3.cluster_index = 2;
    test4.cluster_index = 3;

    // copy test file contents to buffer
    FILE *f = fopen("testfile1.bin", "rb");
    fseek(f, 0, SEEK_END);
    long filelen = ftell(f);
    fseek(f, 0, SEEK_SET);
    test1.sectors_used = ceil(filelen / BYTES_PER_SECTOR) + 1;
    int offset = data_start_address + (test1.cluster_index * max_filesize);
    fread(buffer + offset, 1, filelen, f);
    fclose(f);
    f = fopen("testfile2.bin", "rb");
    fseek(f, 0, SEEK_END);
    filelen = ftell(f);
    fseek(f, 0, SEEK_SET);
    test2.sectors_used = ceil(filelen / BYTES_PER_SECTOR) + 1;
    offset = data_start_address + (test2.cluster_index * max_filesize);
    fread(buffer + offset, 1, filelen, f);
    fclose(f);
    f = 0;
    f = fopen("3100_hello_world.rom", "rb");
    fseek(f, 0, SEEK_END);
    filelen = ftell(f);
    fseek(f, 0, SEEK_SET);
    test3.sectors_used = ceil(filelen / BYTES_PER_SECTOR) + 1;
    offset = data_start_address + (test3.cluster_index * max_filesize);
    fread(buffer + offset, 1, filelen, f);
    fclose(f);
    f = 0;
    test4.sectors_used = 3;

    // write to file
    g_fout = fopen("test.bin", "wb");
    memcpy(buffer + prop_start_address, &fsprop, sizeof(FS_PROPERTIES_NODE));
    memcpy(buffer + root_start_address + (test1.cluster_index * root_node_size), &test1, sizeof(ROOT_NODE));
    memcpy(buffer + root_start_address + (test2.cluster_index * root_node_size), &test2, sizeof(ROOT_NODE));
    memcpy(buffer + root_start_address + (test3.cluster_index * root_node_size), &test3, sizeof(ROOT_NODE));
    memcpy(buffer + root_start_address + (test4.cluster_index * root_node_size), &test4, sizeof(ROOT_NODE));
    fwrite(buffer, 1, volume_size, g_fout);
    fflush(g_fout);
    fclose(g_fout);

    free(buffer);
    buffer = 0;

    return 0;
}
