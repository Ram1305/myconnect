// import 'package:flutter/material.dart';
// import 'package:flutter_svg/flutter_svg.dart';
// import 'package:carousel_slider/carousel_slider.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import '../config/app_config.dart';
// import '../utils/theme.dart';
// import 'family_members_screen.dart';
// import 'blogs_screen.dart';
// import 'family_locations_screen.dart';
// import 'events_screen.dart';
//
// class CustomerDashboard extends StatefulWidget {
//   final String userId;
//
//   const CustomerDashboard({
//     super.key,
//     required this.userId,
//   });
//
//   @override
//   State<CustomerDashboard> createState() => _CustomerDashboardState();
// }
//
// class _CustomerDashboardState extends State<CustomerDashboard> with TickerProviderStateMixin {
//   int myActiveIndex = 0;
//   bool _isLoading = true;
//   List<String> bannerList = [];
//
//   late AnimationController _carouselAnimationController;
//   late Animation<Offset> _carouselSlideAnimation;
//   late AnimationController _gridAnimationController;
//   late Animation<Offset> _gridSlideAnimation;
//   late AnimationController _buttonAnimationController;
//   late Animation<Offset> _buttonSlideAnimation;
//
//   // Quick Links data
//   final List<Map<String, dynamic>> quickLinksData = [
//     {'head': 'Family', 'bottom': 'Members', 'icon': 'assets/icons/familymembers.svg'},
//     {'head': 'Family', 'bottom': 'Location', 'icon': 'assets/icons/familylocation.svg'},
//     {'head': 'Event', 'bottom': 'Calendar', 'icon': 'assets/icons/eventcalendar.svg'},
//     {'head': 'Gallery', 'bottom': '', 'icon': 'assets/icons/gallery.svg'},
//     {'head': 'Blogs', 'bottom': '', 'icon': 'assets/icons/blogs.svg'},
//     {'head': 'About', 'bottom': 'Us', 'icon': 'assets/icons/aboutus.svg'},
//     {'head': 'Temple', 'bottom': '', 'icon': Icons.temple_buddhist}, // Using Material icon for temple
//   ];
//
//   @override
//   void initState() {
//     super.initState();
//     fetchBanners();
//
//     // Initialize animations
//     _carouselAnimationController = AnimationController(
//       duration: const Duration(milliseconds: 600),
//       vsync: this,
//     );
//     _carouselSlideAnimation = Tween<Offset>(
//       begin: const Offset(0, -1),
//       end: Offset.zero,
//     ).animate(CurvedAnimation(
//       parent: _carouselAnimationController,
//       curve: Curves.easeInOut,
//     ));
//
//     _gridAnimationController = AnimationController(
//       duration: const Duration(milliseconds: 800),
//       vsync: this,
//     );
//     _gridSlideAnimation = Tween<Offset>(
//       begin: const Offset(0, 1),
//       end: Offset.zero,
//     ).animate(CurvedAnimation(
//       parent: _gridAnimationController,
//       curve: Curves.easeInOut,
//     ));
//
//     _buttonAnimationController = AnimationController(
//       duration: const Duration(milliseconds: 1000),
//       vsync: this,
//     );
//     _buttonSlideAnimation = Tween<Offset>(
//       begin: const Offset(0, 1),
//       end: Offset.zero,
//     ).animate(CurvedAnimation(
//       parent: _buttonAnimationController,
//       curve: Curves.easeInOut,
//     ));
//
//     // Start animations
//     Future.delayed(const Duration(milliseconds: 100), () {
//       _carouselAnimationController.forward();
//       _gridAnimationController.forward();
//       _buttonAnimationController.forward();
//     });
//   }
//
//   @override
//   void dispose() {
//     _carouselAnimationController.dispose();
//     _gridAnimationController.dispose();
//     _buttonAnimationController.dispose();
//     super.dispose();
//   }
//
//   Future<void> fetchBanners() async {
//     setState(() {
//       _isLoading = true;
//     });
//
//     final String apiUrl = '${AppConfig.baseUrl}/vendor/getbanner';
//
//     try {
//       final response = await http.get(Uri.parse(apiUrl));
//
//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         if (data['banners'] != null) {
//           setState(() {
//             bannerList = List<String>.from(
//               data['banners'].map((banner) => banner['image']),
//             );
//             _isLoading = false;
//           });
//         } else {
//           setState(() {
//             _isLoading = false;
//           });
//         }
//       } else {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     } catch (e) {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }
//
//   Widget _buildSkeletonLoader() {
//     return Container(
//       height: MediaQuery.of(context).size.height * 0.17,
//       decoration: BoxDecoration(
//         color: Colors.grey[300],
//         borderRadius: BorderRadius.circular(5),
//       ),
//       child: const Center(
//         child: CircularProgressIndicator(),
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text("Home"),
//       ),
//       body: SingleChildScrollView(
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.center,
//           children: [
//             // Carousel/Poster Scroll Section
//             SlideTransition(
//               position: _carouselSlideAnimation,
//               child: Padding(
//                 padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
//                 child: Column(
//                   children: [
//                     _isLoading
//                         ? _buildSkeletonLoader()
//                         : bannerList.isEmpty
//                             ? Container(
//                                 height: MediaQuery.of(context).size.height * 0.17,
//                                 decoration: BoxDecoration(
//                                   color: Colors.grey[200],
//                                   borderRadius: BorderRadius.circular(5),
//                                 ),
//                                 child: const Center(
//                                   child: Text('No banners available'),
//                                 ),
//                               )
//                             : CarouselSlider(
//                                 items: bannerList.map((banner) {
//                                   return Container(
//                                     decoration: BoxDecoration(
//                                       borderRadius: BorderRadius.circular(5),
//                                       border: Border.all(
//                                         color: AppTheme.primaryColor.withOpacity(0.3),
//                                         width: 0.5,
//                                       ),
//                                     ),
//                                     child: ClipRRect(
//                                       borderRadius: BorderRadius.circular(5),
//                                       child: Image.network(
//                                         banner,
//                                         fit: BoxFit.cover,
//                                         width: double.infinity,
//                                         errorBuilder: (context, error, stackTrace) {
//                                           return const Icon(Icons.error);
//                                         },
//                                       ),
//                                     ),
//                                   );
//                                 }).toList(),
//                                 options: CarouselOptions(
//                                   height: MediaQuery.of(context).size.height * 0.17,
//                                   autoPlay: true,
//                                   enableInfiniteScroll: true,
//                                   viewportFraction: 1.0,
//                                   scrollPhysics: const BouncingScrollPhysics(),
//                                   autoPlayCurve: Curves.fastOutSlowIn,
//                                   autoPlayAnimationDuration: const Duration(milliseconds: 800),
//                                   onPageChanged: (index, reason) {
//                                     setState(() {
//                                       myActiveIndex = index;
//                                     });
//                                   },
//                                 ),
//                               ),
//                     if (bannerList.isNotEmpty) ...[
//                       const SizedBox(height: 10),
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: bannerList.asMap().entries.map((entry) {
//                           return Container(
//                             width: myActiveIndex == entry.key ? 20 : 12,
//                             height: 8.0,
//                             margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
//                             decoration: BoxDecoration(
//                               borderRadius: BorderRadius.circular(10),
//                               color: AppTheme.primaryColor.withOpacity(
//                                   myActiveIndex == entry.key ? 0.9 : 0.4),
//                             ),
//                           );
//                         }).toList(),
//                       ),
//                     ],
//                   ],
//                 ),
//               ),
//             ),
//
//             const SizedBox(height: 10),
//
//             // Quick Links Section
//             SlideTransition(
//               position: _gridSlideAnimation,
//               child: Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 15),
//                 child: Column(
//                   children: [
//                     Row(
//                       children: [
//                         Text(
//                           'Quick Links',
//                           style: GoogleFonts.poppins(
//                             fontWeight: FontWeight.bold,
//                             fontSize: 18,
//                             color: Colors.black,
//                           ),
//                         ),
//                         const SizedBox(width: 5),
//                         Icon(
//                           Icons.arrow_circle_right,
//                           size: 20,
//                           color: AppTheme.primaryColor,
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 10),
//                     GridView.builder(
//                       physics: const NeverScrollableScrollPhysics(),
//                       shrinkWrap: true,
//                       gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                         crossAxisCount: 4,
//                         crossAxisSpacing: 10.0,
//                         mainAxisSpacing: 10.0,
//                         childAspectRatio: 1.0,
//                       ),
//                       itemCount: quickLinksData.length,
//                       itemBuilder: (context, index) {
//                         return _buildGridItem(context, index);
//                       },
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//
//             const SizedBox(height: 30),
//
//             // Three Elevated Buttons Section
//             SlideTransition(
//               position: _buttonSlideAnimation,
//               child: Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 15),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       children: [
//                         Text(
//                           'Search Options',
//                           style: GoogleFonts.poppins(
//                             fontWeight: FontWeight.bold,
//                             fontSize: 18,
//                             color: Colors.black,
//                           ),
//                         ),
//                         const SizedBox(width: 5),
//                         Icon(
//                           Icons.arrow_circle_right,
//                           size: 20,
//                           color: AppTheme.primaryColor,
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 15),
//                     // Search with Candidate
//                     _buildSearchButton(
//                       icon: Icons.person_search,
//                       title: 'Search with Candidate',
//                       subtitle: 'Find by candidate name',
//                       onTap: () {
//                         // Navigate to search screen with candidate option
//                         _navigateToSearch('candidate');
//                       },
//                     ),
//                     const SizedBox(height: 12),
//                     // Search with Father Name
//                     _buildSearchButton(
//                       icon: Icons.family_restroom,
//                       title: 'Search with Father Name',
//                       subtitle: 'Find by father\'s name',
//                       onTap: () {
//                         // Navigate to search screen with father name option
//                         _navigateToSearch('father');
//                       },
//                     ),
//                     const SizedBox(height: 12),
//                     // Search with Address
//                     _buildSearchButton(
//                       icon: Icons.location_on,
//                       title: 'Search with Address',
//                       subtitle: 'Find by location',
//                       onTap: () {
//                         // Navigate to search screen with address option
//                         _navigateToSearch('address');
//                       },
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//
//             const SizedBox(height: 30),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildGridItem(BuildContext context, int index) {
//     final item = quickLinksData[index];
//
//     return GestureDetector(
//       onTap: () {
//         _handleQuickLinkTap(index);
//       },
//       child: Container(
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(10),
//           border: Border.all(
//             color: AppTheme.primaryColor.withOpacity(0.3),
//             width: 1,
//           ),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.05),
//               blurRadius: 5,
//               offset: const Offset(0, 2),
//             ),
//           ],
//         ),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           crossAxisAlignment: CrossAxisAlignment.center,
//           children: [
//             item['icon'] is String
//                 ? SvgPicture.asset(
//                     item['icon'],
//                     height: 40,
//                     width: 40,
//
//                   )
//                 : Icon(
//                     item['icon'] as IconData,
//                     size: 40,
//                     // color: AppTheme.primaryColor,
//                   ),
//             const SizedBox(height: 8),
//             Column(
//               children: [
//                 Text(
//                   item['head']!,
//                   style: GoogleFonts.poppins(
//                     fontSize: 11,
//                     fontWeight: FontWeight.w500,
//                     color: Colors.black,
//                     height: 1.1,
//                   ),
//                   textAlign: TextAlign.center,
//                 ),
//                 if (item['bottom'] != null && item['bottom']!.isNotEmpty)
//                   Text(
//                     item['bottom']!,
//                     style: GoogleFonts.poppins(
//                       fontSize: 11,
//                       fontWeight: FontWeight.w500,
//                       color: Colors.black,
//                       height: 1.1,
//                     ),
//                     textAlign: TextAlign.center,
//                   ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildSearchButton({
//     required IconData icon,
//     required String title,
//     required String subtitle,
//     required VoidCallback onTap,
//   }) {
//     return ElevatedButton(
//       onPressed: onTap,
//       style: ElevatedButton.styleFrom(
//         backgroundColor: Colors.white,
//         foregroundColor: AppTheme.primaryColor,
//         elevation: 3,
//         padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(12),
//           side: BorderSide(
//             color: AppTheme.primaryColor.withOpacity(0.3),
//             width: 1,
//           ),
//         ),
//       ),
//       child: Row(
//         children: [
//           Container(
//             padding: const EdgeInsets.all(10),
//             decoration: BoxDecoration(
//               color: AppTheme.primaryColor.withOpacity(0.1),
//               borderRadius: BorderRadius.circular(10),
//             ),
//             child: Icon(
//               icon,
//               size: 28,
//               color: AppTheme.primaryColor,
//             ),
//           ),
//           const SizedBox(width: 15),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   title,
//                   style: GoogleFonts.poppins(
//                     fontSize: 15,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.black,
//                   ),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   subtitle,
//                   style: GoogleFonts.poppins(
//                     fontSize: 12,
//                     color: Colors.grey[600],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           Icon(
//             Icons.arrow_forward_ios,
//             size: 18,
//             color: AppTheme.primaryColor,
//           ),
//         ],
//       ),
//     );
//   }
//
//   void _handleQuickLinkTap(int index) {
//     switch (index) {
//       case 0: // Family Members
//         Navigator.push(
//           context,
//           MaterialPageRoute(
//             builder: (context) => const FamilyMembersScreen(),
//           ),
//         );
//         break;
//       case 1: // Family Location
//         Navigator.push(
//           context,
//           MaterialPageRoute(
//             builder: (context) => const FamilyLocationsScreen(),
//           ),
//         );
//         break;
//       case 2: // Event Calendar
//         Navigator.push(
//           context,
//           MaterialPageRoute(
//             builder: (context) => const EventsScreen(),
//           ),
//         );
//         break;
//       case 3: // Gallery
//         // TODO: Navigate to Gallery screen
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Gallery feature coming soon')),
//         );
//         break;
//       case 4: // Blogs
//         Navigator.push(
//           context,
//           MaterialPageRoute(
//             builder: (context) => const BlogsScreen(),
//           ),
//         );
//         break;
//       case 5: // About Us
//         // TODO: Navigate to About Us screen
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('About Us feature coming soon')),
//         );
//         break;
//       case 6: // Temple
//         // TODO: Navigate to Temple screen
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Temple feature coming soon')),
//         );
//         break;
//     }
//   }
//
//   void _navigateToSearch(String searchType) {
//     // TODO: Navigate to search screen with the appropriate search type
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('Search with $searchType feature coming soon'),
//       ),
//     );
//   }
// }
//
