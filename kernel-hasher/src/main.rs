use linux_loader::{
    bootparam::setup_header,
    elf::{self, elf64_phdr},
};
use sha2::{Digest, Sha256};
use std::{
    env,
    fs::File,
    io::{self, Read, Seek, SeekFrom, Write},
    mem,
};
use vm_memory::ByteValued;
use vm_memory::Bytes;

#[derive(PartialEq, Copy, Clone)]
enum KernelType {
    BzImage,
    Direct,
}

#[derive(Debug)]
enum Error {
    SeekKernelStart,
    ReadKernelDataStruct(&'static str),
    InvalidElfMagicNumber,
    BigEndianElfOnLittle,
    InvalidProgramHeaderSize,
    InvalidProgramHeaderOffset,
    SeekProgramHeader,
}

const BZIMAGE_HEADER_OFFSET: u64 = 0x1f1;
const BZIMAGE_HEADER_MAGIC: u32 = 0x53726448;

fn main() {
    let args: Vec<String> = env::args().collect();
    if let Some(path) = args.get(1) {
        match File::open(path) {
            Ok(mut f) => {
                hash_kernel(&mut f).unwrap();
            }
            Err(e) => {
                eprintln!("Error opening file: {}", e.to_string());
            }
        }
    } else {
        eprintln!("Usage: {} <kernel-path>", args.get(0).unwrap());
    }
}

fn hash_kernel(kernel: &mut File) -> Result<(), Error> {
    match get_kernel_type(kernel) {
        KernelType::BzImage => hash_bzimage(kernel),
        KernelType::Direct => hash_elf(kernel),
    }
}

fn get_kernel_type<F>(kernel_image: &mut F) -> KernelType
where
    F: Read + Seek,
{
    let mut kernel_type = KernelType::Direct;
    //determine if kernel file is bzImage or uncompressed
    //Assume bzImage first
    let mut bz_header = setup_header::default();
    kernel_image
        .seek(SeekFrom::Start(BZIMAGE_HEADER_OFFSET))
        .unwrap();

    bz_header
        .as_bytes()
        .read_from(0, kernel_image, mem::size_of::<setup_header>())
        .unwrap();

    if bz_header.header == BZIMAGE_HEADER_MAGIC {
        kernel_type = KernelType::BzImage;
    }

    kernel_type
}

fn hash_bzimage<F>(kernel_image: &mut F) -> Result<(), Error>
where
    F: Read + Seek,
{
    let mut hasher = Sha256::new();
    kernel_image.seek(SeekFrom::Start(0)).unwrap();
    let len = kernel_image.seek(SeekFrom::End(0)).unwrap();
    kernel_image.seek(SeekFrom::Start(0)).unwrap();

    let mut buf = vec![0u8; len as usize];
    kernel_image.read_exact(&mut buf).unwrap();
    hasher.update(buf);
    let hash = hasher.finalize();

    let mut stdout = io::stdout().lock();
    stdout.write_all(&hash).unwrap();
    Ok(())
}

fn hash_elf<F>(kernel_image: &mut F) -> Result<(), Error>
where
    F: Read + Seek,
{
    kernel_image
        .seek(SeekFrom::Start(0))
        .map_err(|_| Error::SeekKernelStart)?;

    let mut ehdr = elf::Elf64_Ehdr::default();
    ehdr.as_bytes()
        .read_from(0, kernel_image, mem::size_of::<elf::Elf64_Ehdr>())
        .map_err(|_| Error::ReadKernelDataStruct("Failed to read ELF header"))?;

    if ehdr.e_ident[elf::EI_MAG0 as usize] != elf::ELFMAG0 as u8
        || ehdr.e_ident[elf::EI_MAG1 as usize] != elf::ELFMAG1
        || ehdr.e_ident[elf::EI_MAG2 as usize] != elf::ELFMAG2
        || ehdr.e_ident[elf::EI_MAG3 as usize] != elf::ELFMAG3
    {
        return Err(Error::InvalidElfMagicNumber);
    }
    if ehdr.e_ident[elf::EI_DATA as usize] != elf::ELFDATA2LSB as u8 {
        return Err(Error::BigEndianElfOnLittle);
    }
    if ehdr.e_phentsize as usize != mem::size_of::<elf::Elf64_Phdr>() {
        return Err(Error::InvalidProgramHeaderSize);
    }
    if (ehdr.e_phoff as usize) < mem::size_of::<elf::Elf64_Ehdr>() {
        // If the program header is backwards, bail.
        return Err(Error::InvalidProgramHeaderOffset);
    }

    let mut hasher = Sha256::new();
    hasher.update(ehdr.as_slice());
    // let mut hash = hasher.finalize_reset();

    // println!("ELF header hash: {:02x?}", hash);
    let mut stdout = io::stdout().lock();
    // stdout.write_all(&hash).unwrap();

    kernel_image
        .seek(SeekFrom::Start(ehdr.e_phoff))
        .map_err(|_| Error::SeekProgramHeader)?;

    let mut phdrs: Vec<elf64_phdr> = Vec::new();
    let phdr_sz = mem::size_of::<elf::Elf64_Phdr>();
    for _ in 0usize..ehdr.e_phnum as usize {
        let mut phdr = elf::Elf64_Phdr::default();
        phdr.as_bytes()
            .read_from(0, kernel_image, phdr_sz)
            .map_err(|_| Error::ReadKernelDataStruct("Failed to read ELF program header"))?;
        phdrs.push(phdr);
        hasher.update(phdr.as_slice());
    }
    // hash = hasher.finalize_reset();

    // println!("Program headers hash: {:02x?}", hash);
    // stdout.write_all(&hash).unwrap();

    for phdr in phdrs {
        if phdr.p_type & elf::PT_LOAD == 0 || phdr.p_filesz == 0 {
            continue;
        }
        // println!("size: {}", phdr.p_filesz);
        let file_offset = phdr.p_offset;
        kernel_image
            .seek(SeekFrom::Start(file_offset))
            .map_err(|_| Error::SeekKernelStart)?;

        let mut buf = vec![0u8; phdr.p_filesz.try_into().unwrap()];

        kernel_image
            .read_exact(&mut buf)
            .map_err(|_| Error::ReadKernelDataStruct("Failed to read loadable segment"))?;

        hasher.update(buf);
    }

    let hash = hasher.finalize_reset();
    // println!("Loadable segments hash: {:02x?}", hash);
    stdout.write_all(&hash).unwrap();

    Ok(())
}
