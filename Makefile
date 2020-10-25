all:
	xa -o tfs.rom tfs.asm

clean:
	rm -f tfs.rom
	rm -f memdump

sim-install:
	cp tfs.rom ../romfiles/1000_tfs.rom

upload-install:
	cp tfs.rom ../tpc_uploader/1000_tfs.rom
