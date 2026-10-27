import 'package:maseef_app/models/listing.dart';

/// The five real listings supplied for MASEEF.
///
/// [Listing.photoAssets] uses the image files that are actually in
/// assets/images. Two of those files differ slightly from the names first
/// written down: Celine Villa is CelineVilla.png, and Green Garden Villa is
/// GreenGarden.png.
///
/// Hareem Sultan's gallery uses the seven photos in assets/images/HareemSultan.
/// Pool.jpg is the cover. The older HareemSultan.png file is left in place.
const List<String> hareemSultanGallery = [
  'assets/images/HareemSultan/Pool.jpg',
  'assets/images/HareemSultan/livingRoom.jpg',
  'assets/images/HareemSultan/kitchen.jpg',
  'assets/images/HareemSultan/ROOM1.jpg',
  'assets/images/HareemSultan/ROOM2.jpg',
  'assets/images/HareemSultan/ROOM3.jpg',
  'assets/images/HareemSultan/bathRoom.jpg',
];

const List<String> hareemSultanAmenities = [
  'outdoor_seating',
  'equipped_kitchen',
  'swimming_pool',
  'wifi',
  'billiards',
  'childrens_pool',
  'childrens_play_equipment',
  'barbecue_grill',
  'private_parking',
];

const List<Listing> realListings = [
  Listing(
    id: 'hareem-sultan',
    name: 'Hareem Sultan Resort',
    governorate: 'نابلس',
    locality: 'النصارية',
    whatsapp: '+970566232380',
    facebookUrl: 'https://www.facebook.com/share/1BQ7hugSBH/?mibextid=LQQJ4d',
    referencedImageFilename: 'Pool.jpg',
    photoAssets: hareemSultanGallery,
    bedrooms: 3,
    amenityKeys: hareemSultanAmenities,
  ),
  Listing(
    id: 'w-villa',
    name: 'W Villa',
    governorate: 'نابلس',
    locality: 'طلوزة',
    whatsapp: '+970597200700',
    instagramUrl:
        'https://www.instagram.com/w.villa.nablus?psln=YTB2MmtlOTZncWM0',
    referencedImageFilename: 'W.png',
    photoAssets: ['assets/images/W.png'],
  ),
  Listing(
    id: 'celine-villa',
    name: 'Celine Villa',
    governorate: 'جنين',
    locality: 'جنين',
    whatsapp: '+970566600051',
    instagramUrl:
        'https://www.instagram.com/celinevilla_?xtok=eWl3NzV6bTNrdmU3',
    facebookUrl: 'https://www.facebook.com/share/1Mog4HByik/?mibextid=LQQJ4d',
    referencedImageFilename: 'CelineVilla.png',
    photoAssets: ['assets/images/CelineVilla.png'],
  ),
  Listing(
    id: 'haifa-villa',
    name: 'Haifa Villa',
    governorate: 'جنين',
    locality: 'جنين',
    whatsapp: '+972594796885',
    instagramUrl: 'https://www.instagram.com/haifa_villa?xtok=NWhoYXE4OGVpcGp4',
    facebookUrl: 'https://www.facebook.com/share/18QMhUHLym/?mibextid=LQQJ4d',
    referencedImageFilename: 'Haifa.png',
    photoAssets: ['assets/images/Haifa.png'],
  ),
  Listing(
    id: 'green-garden',
    name: 'Green Garden Villa',
    governorate: 'جنين',
    locality: 'دير غزالة',
    whatsapp: '0597302415',
    facebookUrl: 'https://www.facebook.com/share/1E3JVgtNco/?mibextid=LQQJ4d',
    instagramUrl:
        'https://www.instagram.com/green_garden.villa?psln=azQzYXI3N3RuM2hi',
    referencedImageFilename: 'GreenGarden.png',
    photoAssets: ['assets/images/GreenGarden.png'],
  ),
];

class ListingSource {
  const ListingSource();

  Future<List<Listing>> load() async => realListings;
}
