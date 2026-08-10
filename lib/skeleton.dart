import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class ReportCardSkeleton extends StatelessWidget {
  const ReportCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const SkeletonBox(width: 44, height: 44, radius: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(height: 14, width: 160),
                SizedBox(height: 8),
                SkeletonBox(height: 12, width: 120),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SkeletonBox(width: 52, height: 20, radius: 20),
              SizedBox(height: 8),
              SkeletonBox(width: 40, height: 10),
            ],
          ),
        ],
      ),
    );
  }
}

class ReportListSkeleton extends StatelessWidget {
  final int count;

  const ReportListSkeleton({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Column(
        children: List.generate(count, (_) => const ReportCardSkeleton()),
      ),
    );
  }
}

class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(28, topInset + 36, 28, 24),
          child: Column(
            children: [
              const SkeletonBox(height: 120, width: 120, radius: 60),
              const SizedBox(height: 18),
              const SkeletonBox(height: 30, width: 120),
              const SizedBox(height: 10),
              const SkeletonBox(height: 14, width: 140),
              const SizedBox(height: 8),
              const SkeletonBox(height: 12, width: 160),
              const SizedBox(height: 40),
              ...List.generate(
                5,
                (_) => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 15),
                  child: Row(
                    children: [
                      SkeletonBox(height: 22, width: 22, radius: 6),
                      SizedBox(width: 16),
                      Expanded(child: SkeletonBox(height: 16)),
                      SizedBox(width: 12),
                      SkeletonBox(height: 16, width: 16, radius: 4),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LeaderboardSkeleton extends StatelessWidget {
  const LeaderboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: 220,
              color: Colors.white,
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                child: Column(
                  children: List.generate(
                    5,
                    (_) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        children: [
                          SkeletonBox(width: 28, height: 16),
                          SizedBox(width: 12),
                          SkeletonBox(width: 40, height: 40, radius: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: SkeletonBox(height: 14, width: 120),
                          ),
                          SkeletonBox(width: 36, height: 14),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
