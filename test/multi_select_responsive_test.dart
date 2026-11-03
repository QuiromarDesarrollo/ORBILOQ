import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/shared/widgets/multi_select_filter.dart';
void main(){
 for(final width in [320.0,390.0,768.0]) {
 testWidgets('Filtro y orden utilizables a $width', (tester) async {
 tester.view.physicalSize=Size(width,844);tester.view.devicePixelRatio=1;
 addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
 await tester.pumpWidget(MaterialApp(home:Builder(builder:(context)=>Scaffold(body:TextButton(onPressed:()=>showMultiSelectFilter<String>(context,title:'Productos',options:['Producto A','Producto B'],selected:{},labelOf:(v)=>v),child:const Text('Abrir'))))));
 await tester.tap(find.text('Abrir'));await tester.pumpAndSettle();
 expect(tester.takeException(),isNull);
 await tester.ensureVisible(find.byTooltip('Descendente'));
 await tester.tap(find.byTooltip('Descendente'));await tester.pumpAndSettle();
 expect(tester.takeException(),isNull);
 });
 }
}

