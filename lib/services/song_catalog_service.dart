class SongCatalogService {
  static const List<Map<String, String>> _songs = [
    {
      'title': 'Dadalhin',
      'artist': 'Regine Velasquez',
      'image':
          'https://media.philstar.com/photos/2022/04/19/regine-1_2022-04-19_17-19-51.jpg',
      'hasAudio': 'true',
    },
    {
      'title': 'Paalam Muna Sandali',
      'artist': 'Darren Espanto',
      'image':
          'https://tse4.mm.bing.net/th/id/OIP.X4OeqoB_8615vepJpu2zdQHaE7?rs=1&pid=ImgDetMain&o=7&rm=3',
    },
    {
      'title': 'Nasa Iyo Na Ang Lahat',
      'artist': 'Daniel Padilla',
      'image':
          'https://images.genius.com/e817d67292e5c1ac1e72b0c8573161e5.900x900x1.jpg',
      'hasAudio': 'true',
    },
    {
      'title': 'Ulap',
      'artist': 'Rob Daniel',
      'image':
          'https://tse3.mm.bing.net/th/id/OIP.4AnzA3S0-AUEBFjst492KwAAAA?rs=1&pid=ImgDetMain&o=7&rm=3',
    },
    {
      'title': 'Fallen',
      'artist': 'Lola Amour',
      'image':
          'https://images.genius.com/b62c08396330faf55dae7e6a73b26324.1000x1000x1.png',
    },
    {
      'title': 'Binibini',
      'artist': 'Arthur Nery',
      'image':
          'https://i.pinimg.com/736x/c4/51/fd/c451fd1b67b8e80830aaca56188e46d8.jpg',
    },
    {
      'title': 'Kumpas',
      'artist': 'Moira Dela Torre',
      'image':
          'https://tse2.mm.bing.net/th/id/OIP.2Uaip4XK2mxVqOEL_zu4cAHaFj?rs=1&pid=ImgDetMain&o=7&rm=3',
    },
    {
      'title': 'Randomantic',
      'artist': 'James Reid',
      'image':
          'https://images.genius.com/f428806fd40d83f4a6f934680bdbd7e8.1000x1000x1.jpg',
    },
    {
      'title': 'Ikaw Lang',
      'artist': 'NOBITA',
      'image':
          'https://i.scdn.co/image/ab67616d0000b273a44cfbb6f42b4a184e6a29a1',
    },
    {
      'title': 'Mundo',
      'artist': 'IV of Spades',
      'image':
          'https://i.scdn.co/image/ab67616d0000b27394d280d8f53a4f8591387213',
    },
    {
      'title': 'Araw-Araw',
      'artist': 'Ben&Ben',
      'image':
          'https://i.scdn.co/image/ab67616d0000b273d8b4a5a9a1a1a1a1a1a1a1a1',
    },
    {
      'title': 'Kathang Isip',
      'artist': 'Ben&Ben',
      'image':
          'https://i.scdn.co/image/ab67616d0000b273d8b4a5a9a1a1a1a1a1a1a1a1',
    },
    {
      'title': 'Tahanan',
      'artist': 'Adie',
      'image':
          'https://i.scdn.co/image/ab67616d0000b2735ac9f1b521c247c1c7a15f46',
    },
    {
      'title': 'Buwan',
      'artist': 'Juan Karlos',
      'image':
          'https://i.scdn.co/image/ab67616d0000b2737e11d590e0b4cf8e0a06286d',
    },
    {
      'title': 'Pano',
      'artist': 'Zack Tabudlo',
      'image':
          'https://i.scdn.co/image/ab67616d0000b2732c2c0a13f48e0db4d1d23cc5',
    },
    {
      'title': 'Ere',
      'artist': 'Juan Karlos',
      'image':
          'https://i.scdn.co/image/ab67616d0000b2737e11d590e0b4cf8e0a06286d',
    },
    {
      'title': 'Isa Pang Araw',
      'artist': 'BINI',
      'image':
          'https://i.scdn.co/image/ab67616d0000b273a0e2f3dc5f96e8e2e3a6b9d5',
    },
    {
      'title': 'With A Smile',
      'artist': 'Eraserheads',
      'image':
          'https://i.scdn.co/image/ab67616d0000b2739e495fb707973f3d1382c4b1',
    },
    {
      'title': 'Ang Huling El Bimbo',
      'artist': 'Eraserheads',
      'image':
          'https://i.scdn.co/image/ab67616d0000b2739e495fb707973f3d1382c4b1',
    },
    {
      'title': 'Anak',
      'artist': 'Freddie Aguilar',
      'image':
          'https://i.scdn.co/image/ab67616d0000b273cd5b8e7c19f5e3c5e01c8f1d',
    },
  ];

  static List<Map<String, String>> get allSongs => _songs;

  static List<Map<String, String>> get songsWithAudio =>
      _songs.where((s) => s['hasAudio'] == 'true').toList();

  static List<Map<String, String>> search(String query) {
    final q = query.toLowerCase();
    return _songs
        .where(
          (s) =>
              (s['title'] ?? '').toLowerCase().contains(q) ||
              (s['artist'] ?? '').toLowerCase().contains(q),
        )
        .toList();
  }
}
