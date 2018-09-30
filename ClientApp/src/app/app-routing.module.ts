import { NgModule } from '@angular/core';
import { RouterModule, Routes } from '@angular/router';

import { ProductDetailComponent } from './product-detail/product-detail.component';
import { ProductThumbnailListComponent } from './product-thumbnail-list/product-thumbnail-list.component';

const routes: Routes = [
  { path: 'product/:id', component: ProductDetailComponent },
  { path: 'products', component: ProductThumbnailListComponent }
];

@NgModule({
  imports: [RouterModule.forRoot(routes)],
  exports: [RouterModule]
})
export class AppRoutingModule { }
