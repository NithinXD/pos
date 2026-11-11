import 'package:flutter/material.dart';
import '../models/table_model.dart';

class TableCard extends StatelessWidget {
  final TableModel table;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onPrint;
  final String currency;

  const TableCard({
    super.key,
    required this.table,
    required this.onTap,
    this.onLongPress,
    this.onPrint,
    this.currency = '₹',
  });

  // Green / Deep Teal for closed / available tables (matching wireframe)
  static const Color closedColor = Color(0xFF005C53);
  static const Color closedColorLight = Color(0xFF00756A);

  // Red / Deep Maroon for open / occupied tables & parcels (matching wireframe)
  static const Color openColor = Color(0xFF7A0C0C);
  static const Color openColorLight = Color(0xFF9E1B1B);

  @override
  Widget build(BuildContext context) {
    final isOpen = table.isOpen;
    final isParcel = table.isParcel;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive typography calculation
        final cardWidth = constraints.maxWidth;
        final nameFontSize = (cardWidth * 0.125).clamp(15.0, 24.0);
        final phoneFontSize = (cardWidth * 0.095).clamp(12.0, 18.0);
        final metaFontSize = (cardWidth * 0.075).clamp(10.0, 14.0);

        return Card(
          elevation: isOpen ? 4 : 2,
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
            side: BorderSide(
              color: isOpen ? openColorLight : closedColorLight,
              width: 1.5,
            ),
          ),
          child: Stack(
            children: [
              InkWell(
                onTap: onTap,
                onLongPress: onLongPress,
                splashColor: Colors.white24,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isOpen
                          ? [openColorLight, openColor]
                          : [closedColorLight, closedColor],
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
                  child: isParcel
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Top Row: Token ID + Ready Status
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withAlpha(90),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '#P${table.id % 100 > 0 ? (table.id % 100).toString().padLeft(2, '0') : "01"}',
                                    style: const TextStyle(
                                      color: Color(0xFF67E8F9), // Vibrant cyan
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withAlpha(90),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.access_time, size: 10, color: Colors.white70),
                                      SizedBox(width: 3),
                                      Text(
                                        'Pickup',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            // Center: Customer Name & Phone (Primary focus of wireframe)
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    table.customerName ?? table.name,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: const Color(0xFF67E8F9), // Cyan from wireframe
                                      fontSize: nameFontSize,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.phone, size: 12, color: Colors.white70),
                                    const SizedBox(width: 4),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        table.customerPhone ?? 'No Phone',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: phoneFontSize,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            // Bottom: Price & Items Pill
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(85),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white24, width: 0.8),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '$currency${table.currentTotal.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: metaFontSize,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (table.itemCount > 0) ...[
                                      Text(
                                        ' • ${table.itemCount} items',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: metaFontSize * 0.9,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      // ================= SIT DOWN CARD =================
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Status dot
                            Align(
                              alignment: Alignment.topRight,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isOpen ? Colors.redAccent : Colors.lightGreenAccent,
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isOpen ? Colors.red : Colors.green).withAlpha(120),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Spacer(),
                            // Table Name
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                table.name,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: nameFontSize,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Status readout
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(65),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  isOpen
                                      ? 'Open • $currency${table.currentTotal.toStringAsFixed(0)}'
                                      : 'Closed / Free',
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(230),
                                    fontSize: metaFontSize,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            const Spacer(),
                          ],
                        ),
                ),
              ),

              // Direct Print Bill button on open tables per Sam Biswas
              if (isOpen && onPrint != null)
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Tooltip(
                    message: 'Print Receipt / Bill for ${table.name}',
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onPrint,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7), // Blue button as drawn by Sam Biswas
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black38,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.print_rounded, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Bill',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
