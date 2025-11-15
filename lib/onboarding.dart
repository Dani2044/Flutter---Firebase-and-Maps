import 'package:flutter/material.dart';
import 'register.dart';

class AppBottomBarButtons extends StatelessWidget {
  const AppBottomBarButtons({
    super.key,
    required this.buttons,
    required this.body,
    this.appBar,
  });

  final List<Widget> buttons;
  final Widget body;
  final PreferredSizeWidget? appBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: body,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 24.0,
          horizontal: 16.0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: buttons,
        ),
      ),
    );
  }
}

class ButtonWidget extends StatelessWidget {
  const ButtonWidget({
    super.key,
    this.isFilled = false,
    required this.label,
    required this.callback,
  });

  final bool isFilled;
  final String label;
  final Function()? callback;

  @override
  Widget build(BuildContext context) {
    if (isFilled) {
      return ElevatedButton(
        onPressed: callback,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.black87,
          minimumSize: const Size(double.infinity, 50),
        ),
        child: Text(label),
      );
    } else {
      return ElevatedButton(
        onPressed: callback,
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
        ),
        child: Text(label),
      );
    }
  }
}


class AppData {
  static ValueNotifier<int> onboardingCurrentIndexNotifier =
      ValueNotifier<int>(0);

  static ValueNotifier<double> onboardingSlider1Notifier =
      ValueNotifier<double>(3.0);

  static ValueNotifier<double> onboardingSlider2Notifier =
      ValueNotifier<double>(2.0);
}

class BottomStepperWidget extends StatelessWidget {
  const BottomStepperWidget({
    super.key,
    this.itemCount,
  });

  final int? itemCount;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AppData.onboardingCurrentIndexNotifier,
      builder: (context, currentIndex, child) {
        String label;
        if (itemCount == null) {
          label = 'Last step';
        } else {
          label = 'Step ${currentIndex + 1} of $itemCount';
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white54,
            ),
            textAlign: TextAlign.left,
          ),
        );
      },
    );
  }
}

class OnboardingView1 extends StatefulWidget {
  const OnboardingView1({super.key});

  @override
  State<OnboardingView1> createState() => _OnboardingView1State();
}

class _OnboardingView1State extends State<OnboardingView1> {
  late String mindset;
  late String mindsetTitle;
  late String mindsetDescription;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: AppData.onboardingSlider1Notifier,
      builder: (context, sliderValue, child) {
        _getMindsetValue(sliderValue);
        return Padding(
          padding: const EdgeInsets.all(30.0),
          child: Center(
            child: Column(
              children: [
                const Text(
                  'How is your mindset these days?',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20.0),
                Text(
                  mindset,
                  style: const TextStyle(
                    fontSize: 40,
                  ),
                ),
                SizedBox(
                  height: 100,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FittedBox(
                        child: Text(
                          mindsetTitle,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        child: Text(
                          mindsetDescription,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Slider.adaptive(
                  value: sliderValue,
                  divisions: 4,
                  min: 1,
                  max: 5,
                  onChanged: (double value) {
                    _editSliderValue(value);
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        _editSliderValue(1.0);
                      },
                      child: const Text(
                        'Defeated',
                        style: TextStyle(
                          fontSize: 16,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        _editSliderValue(2.0);
                      },
                      child: const Text(
                        'Doubtful',
                        style: TextStyle(
                          fontSize: 16,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        _editSliderValue(3.0);
                      },
                      child: const Text(
                        'Neutral',
                        style: TextStyle(
                          fontSize: 16,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        _editSliderValue(4.0);
                      },
                      child: const Text(
                        'Optimistic',
                        style: TextStyle(
                          fontSize: 16,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        _editSliderValue(5.0);
                      },
                      child: const Text(
                        'Empowered',
                        style: TextStyle(
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _editSliderValue(double value) {
    setState(() {
      AppData.onboardingSlider1Notifier.value = value;
    });
  }

  void _getMindsetValue(double sliderValue) {
    switch (sliderValue.round()) {
      case 1:
        mindset = '😞';
        mindsetTitle = 'Defeated';
        mindsetDescription = 'You feel stuck and low on energy.';
        break;
      case 2:
        mindset = '😕';
        mindsetTitle = 'Doubtful';
        mindsetDescription = 'You are unsure about your progress.';
        break;
      case 3:
        mindset = '😐';
        mindsetTitle = 'Neutral';
        mindsetDescription = 'You are in the middle, neither low nor high.';
        break;
      case 4:
        mindset = '🙂';
        mindsetTitle = 'Optimistic';
        mindsetDescription = 'You feel hopeful and positive.';
        break;
      case 5:
        mindset = '💪';
        mindsetTitle = 'Empowered';
        mindsetDescription = 'You feel strong, capable and focused.';
        break;
      default:
        mindset = '😐';
        mindsetTitle = 'Neutral';
        mindsetDescription = 'You are in the middle, neither low nor high.';
    }
  }
}

class OnboardingView2 extends StatefulWidget {
  const OnboardingView2({super.key});

  @override
  State<OnboardingView2> createState() => _OnboardingView2State();
}

class _OnboardingView2State extends State<OnboardingView2> {
  late String selection;
  late String selectionTitle;
  late String selectionDescription;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: AppData.onboardingSlider2Notifier,
      builder: (context, sliderValue, child) {
        _getSelectionValue(sliderValue);
        return Padding(
          padding: const EdgeInsets.all(30.0),
          child: Center(
            child: Column(
              children: [
                const Text(
                  'What do you need more help with?',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20.0),
                Text(
                  selection,
                  style: const TextStyle(
                    fontSize: 40,
                  ),
                ),
                SizedBox(
                  height: 100,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FittedBox(
                        child: Text(
                          selectionTitle,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        child: Text(
                          selectionDescription,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Slider.adaptive(
                  value: sliderValue,
                  divisions: 2,
                  min: 1,
                  max: 3,
                  onChanged: (double value) {
                    _editSliderValue(value);
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        _editSliderValue(1.0);
                      },
                      child: const Text(
                        'Offer',
                        style: TextStyle(
                          fontSize: 16,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        _editSliderValue(2.0);
                      },
                      child: const Text(
                        'Traffic',
                        style: TextStyle(
                          fontSize: 16,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        _editSliderValue(3.0);
                      },
                      child: const Text(
                        'Sales',
                        style: TextStyle(
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _editSliderValue(double value) {
    setState(() {
      AppData.onboardingSlider2Notifier.value = value;
    });
  }

  void _getSelectionValue(double sliderValue) {
    switch (sliderValue.round()) {
      case 1:
        selection = '🎯';
        selectionTitle = 'Offer';
        selectionDescription =
            'You want to improve the product or service you sell.';
        break;
      case 2:
        selection = '🚦';
        selectionTitle = 'Traffic';
        selectionDescription =
            'You want more people to discover your offer.';
        break;
      case 3:
        selection = '💰';
        selectionTitle = 'Sales';
        selectionDescription =
            'You want to convert more leads into paying customers.';
        break;
      default:
        selection = '🎯';
        selectionTitle = 'Offer';
        selectionDescription =
            'You want to improve the product or service you sell.';
    }
  }
}

class OnboardingPages extends StatefulWidget {
  const OnboardingPages({
    super.key,
    this.initialPage,
  });

  final int? initialPage;

  @override
  State<OnboardingPages> createState() => _OnboardingPagesState();
}

class _OnboardingPagesState extends State<OnboardingPages>
    with SingleTickerProviderStateMixin {
  late PageController pageController;
  final List<Widget> pages = const [
    OnboardingView1(),
    OnboardingView2(),
  ];

  @override
  void initState() {
    super.initState();
    pageController = PageController(initialPage: widget.initialPage ?? 0);
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomBarButtons(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            if (pageController.page == 0) {
              Navigator.pop(context);
            } else {
              pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.ease,
              );
            }
          },
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Colors.white,
          ),
        ),
        title: const Text('Flutter Pro'),
        bottom: PreferredSize(
          preferredSize: const Size(double.infinity, double.minPositive),
          child: BottomStepperWidget(
            itemCount: pages.length,
          ),
        ),
      ),
      body: PageView.builder(
        physics: const NeverScrollableScrollPhysics(parent: null),
        controller: pageController,
        itemCount: pages.length,
        itemBuilder: (context, index) {
          return pages.elementAt(index);
        },
        onPageChanged: (int value) {
          AppData.onboardingCurrentIndexNotifier.value = value;
        },
      ),
      buttons: [
        ValueListenableBuilder<int>(
          valueListenable: AppData.onboardingCurrentIndexNotifier,
          builder: (context, currentIndex, child) {
            return ButtonWidget(
              isFilled: true,
              label: currentIndex == pages.length - 1
                  ? 'Continue'
                  : 'Next',
              callback: currentIndex == pages.length - 1
                  ? () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) {
                            return const RegisterPage();
                          },
                        ),
                      );
                    }
                  : () {
                      AppData.onboardingCurrentIndexNotifier.value += 1;
                      pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.ease,
                      );
                    },
            );
          },
        ),
      ],
    );
  }
}