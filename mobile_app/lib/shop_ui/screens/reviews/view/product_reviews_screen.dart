import 'package:flutter/material.dart';
import 'package:b2b_store/shop_ui/constants.dart';
import 'package:b2b_store/shop_ui/components/review_card.dart';

class ProductReviewsScreen extends StatelessWidget {
  const ProductReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Product Reviews"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          children: [
            const ReviewCard(
              rating: 4.3,
              numOfReviews: 128,
              numOfFiveStar: 80,
              numOfFourStar: 30,
              numOfThreeStar: 5,
              numOfTwoStar: 4,
              numOfOneStar: 1,
            ),
            const SizedBox(height: defaultPadding),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 5,
              separatorBuilder: (context, index) => const Divider(height: defaultPadding * 2),
              itemBuilder: (context, index) => const UserReviewTile(
                name: "Ankit Sharma",
                rating: 5,
                date: "2 days ago",
                comment: "Excellent quality product! The delivery was very fast and the packaging was great. Highly recommend for business use.",
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UserReviewTile extends StatelessWidget {
  const UserReviewTile({
    super.key,
    required this.name,
    required this.rating,
    required this.date,
    required this.comment,
  });

  final String name, date, comment;
  final int rating;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(date, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: List.generate(
            5,
            (index) => Icon(
              Icons.star,
              size: 16,
              color: index < rating ? Colors.amber : Colors.grey.withValues(alpha: 0.3),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(comment),
      ],
    );
  }
}
