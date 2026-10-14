import 'package:flutter/material.dart';

/// Exact-match animated shimmer skeleton loader for the Shuddham Home Purifier Screen.
/// Matches the real UI format (Header, DeviceCard, 3-column Sensor Telemetry,
/// Last Reading bar, and Fan Relay Card) without any unwanted circular gauges.
class HomeShimmerCard extends StatefulWidget {
  const HomeShimmerCard({super.key});

  @override
  State<HomeShimmerCard> createState() => _HomeShimmerCardState();
}

class _HomeShimmerCardState extends State<HomeShimmerCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildShimmerBox({
    required double width,
    required double height,
    double borderRadius = 8,
    BoxShape shape = BoxShape.rectangle,
  }) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            shape: shape,
            borderRadius: shape == BoxShape.rectangle ? BorderRadius.circular(borderRadius) : null,
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value, 0),
              colors: const [
                Color(0xFFE2E8F0),
                Color(0xFFF1F5F9),
                Color(0xFFE2E8F0),
              ],
              stops: const [0.1, 0.5, 0.9],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Header Skeleton (Logo avatar, Title, Subtitle, Logout action)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildShimmerBox(width: 38, height: 38, borderRadius: 10),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildShimmerBox(width: 90, height: 16, borderRadius: 5),
                      const SizedBox(height: 5),
                      _buildShimmerBox(width: 120, height: 12, borderRadius: 4),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  _buildShimmerBox(width: 34, height: 34, borderRadius: 10),
                  const SizedBox(width: 8),
                  _buildShimmerBox(width: 34, height: 34, borderRadius: 10),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 2. Device Card Skeleton (Exact shape & layout of DeviceCard)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2EEF8)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0077EE).withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon + Device Name + Online Status + Time
                Row(
                  children: [
                    _buildShimmerBox(width: 40, height: 40, borderRadius: 12),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildShimmerBox(width: 160, height: 15, borderRadius: 5),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _buildShimmerBox(width: 7, height: 7, shape: BoxShape.circle),
                              const SizedBox(width: 5),
                              _buildShimmerBox(width: 50, height: 11, borderRadius: 4),
                              const SizedBox(width: 6),
                              _buildShimmerBox(width: 80, height: 10, borderRadius: 4),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Bottom Metric Strip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          _buildShimmerBox(width: 65, height: 13, borderRadius: 4),
                          const SizedBox(width: 14),
                          _buildShimmerBox(width: 65, height: 13, borderRadius: 4),
                        ],
                      ),
                      _buildShimmerBox(width: 55, height: 20, borderRadius: 6),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 3. Telemetry Card Skeleton (Live Sensor Header, 3 Metric Columns, Last Reading, Fan Relay)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2EEF8)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0077EE).withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top header of card: Sensor Status + Mode Chip + 3-dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _buildShimmerBox(width: 10, height: 10, shape: BoxShape.circle),
                        const SizedBox(width: 8),
                        _buildShimmerBox(width: 140, height: 13, borderRadius: 4),
                      ],
                    ),
                    Row(
                      children: [
                        _buildShimmerBox(width: 60, height: 20, borderRadius: 8),
                        const SizedBox(width: 6),
                        _buildShimmerBox(width: 16, height: 20, borderRadius: 4),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // 3 Column Metric Boxes (Inlet TDS, Purified TDS, Temperature)
                Row(
                  children: [
                    // Box 1: Inlet TDS
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildShimmerBox(width: 48, height: 10, borderRadius: 4),
                            const SizedBox(height: 6),
                            _buildShimmerBox(width: 54, height: 16, borderRadius: 4),
                            const SizedBox(height: 4),
                            _buildShimmerBox(width: 42, height: 10, borderRadius: 4),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Box 2: Purified TDS
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildShimmerBox(width: 58, height: 10, borderRadius: 4),
                            const SizedBox(height: 6),
                            _buildShimmerBox(width: 54, height: 16, borderRadius: 4),
                            const SizedBox(height: 4),
                            _buildShimmerBox(width: 38, height: 10, borderRadius: 4),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Box 3: Temperature
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildShimmerBox(width: 54, height: 10, borderRadius: 4),
                            const SizedBox(height: 6),
                            _buildShimmerBox(width: 46, height: 16, borderRadius: 4),
                            const SizedBox(height: 4),
                            _buildShimmerBox(width: 52, height: 10, borderRadius: 4),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Last Data Received Date & Time Banner Skeleton
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      _buildShimmerBox(width: 16, height: 16, borderRadius: 4),
                      const SizedBox(width: 8),
                      _buildShimmerBox(width: 75, height: 12, borderRadius: 4),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildShimmerBox(width: double.infinity, height: 12, borderRadius: 4),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Cooling Fan Relay Container Skeleton
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2EEF8)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fan Row: Icon + Title + Status + Chip
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              _buildShimmerBox(width: 36, height: 36, borderRadius: 10),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildShimmerBox(width: 110, height: 13, borderRadius: 4),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      _buildShimmerBox(width: 7, height: 7, shape: BoxShape.circle),
                                      const SizedBox(width: 5),
                                      _buildShimmerBox(width: 85, height: 11, borderRadius: 4),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                          _buildShimmerBox(width: 55, height: 20, borderRadius: 20),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Two Action Buttons: [Disabled] and [Enable]
                      Row(
                        children: [
                          Expanded(
                            child: _buildShimmerBox(width: double.infinity, height: 38, borderRadius: 10),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildShimmerBox(width: double.infinity, height: 38, borderRadius: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Bottom Unpair link placeholder
                Align(
                  alignment: Alignment.centerRight,
                  child: _buildShimmerBox(width: 70, height: 16, borderRadius: 4),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
