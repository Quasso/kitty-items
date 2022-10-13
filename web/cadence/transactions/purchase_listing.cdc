import FungibleToken from 0xFungibleToken
import NonFungibleToken from 0xNonFungibleToken
import FlowToken from 0xFlowToken
import KittyItems from 0xKittyItems
import NFTStorefrontV2 from 0xNFTStorefront

/*
pub fun getOrCreateCollection(account: AuthAccount): &KittyItems.Collection{NonFungibleToken.Receiver} {
  if let collectionRef = account.borrow<&KittyItems.Collection>(from: KittyItems.CollectionStoragePath) {
    return collectionRef
  }

  // create a new empty collection
  let collection <- KittyItems.createEmptyCollection() as! @KittyItems.Collection

  let collectionRef = &collection as &KittyItems.Collection
  
  // save it to the account
  account.save(<-collection, to: KittyItems.CollectionStoragePath)

  // create a public capability for the collection
  account.link<&KittyItems.Collection{NonFungibleToken.CollectionPublic, KittyItems.KittyItemsCollectionPublic}>(KittyItems.CollectionPublicPath, target: KittyItems.CollectionStoragePath)

  return collectionRef
}
*/

transaction(listingResourceID: UInt64, storefrontAddress: Address) {
  let paymentVault: @FungibleToken.Vault
  let kittyItemsCollection: &KittyItems.Collection{NonFungibleToken.Receiver}
  let storefront: &NFTStorefrontV2.Storefront{NFTStorefrontV2.StorefrontPublic}
  let listing: &NFTStorefrontV2.Listing{NFTStorefrontV2.ListingPublic}

  prepare(account: AuthAccount) {
    // Access the storefront public resource of the seller to purchase the listing.
    self.storefront = getAccount(storefrontAddress)
      .getCapability<&NFTStorefrontV2.Storefront{NFTStorefrontV2.StorefrontPublic}>(
          NFTStorefrontV2.StorefrontPublicPath
      )!
      .borrow()
      ?? panic("Could not borrow Storefront from provided address")

    // Borrow the listing
    self.listing = self.storefront.borrowListing(listingResourceID: listingResourceID) ?? panic("No Offer with that ID in Storefront")
    let price = self.listing.getDetails().salePrice

    // Access the vault of the buyer to pay the sale price of the listing.
    let mainFlowVault = account.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault) ?? panic("Cannot borrow FlowToken vault from account storage")
    self.paymentVault <- mainFlowVault.withdraw(amount: price)

    // Create an empty collection resource and save it to collection storage path
    let collection <- create KittyItems.Collection.createEmptyCollection()
    account.save(<-collection, to: KittyItems.CollectionStoragePath)

    let collectionReceiver = account.borrow<&KittyItems.Collection>(
      from: KittyItems.CollectionStoragePath
    ) ?? panic("Cannot borrow NFT collection receiver from account")

    self.kittyItemsCollection = collectionReceiver
    //self.kittyItemsCollection = getOrCreateCollection(account: account)
  }

  execute {
    let item <- self.listing.purchase(
      payment: <-self.paymentVault,
      commissionRecipient: nil
    )

    self.kittyItemsCollection.deposit(token: <-item)
    self.storefront.cleanupPurchasedListings(listingResourceID: listingResourceID)
  }
}
